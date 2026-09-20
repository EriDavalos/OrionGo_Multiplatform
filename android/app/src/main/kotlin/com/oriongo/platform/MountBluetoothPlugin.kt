package com.oriongo.platform

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.util.UUID
import kotlin.concurrent.thread

/**
 * Bluetooth serial clásico (SPP / RFCOMM) para OrionGo Platform.
 *
 * Se implementa aquí (y no con un plugin externo) para usar exactamente el
 * mismo perfil que la montura Orion y controlar el ciclo de vida del socket.
 */
class MountBluetoothPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val context: Context get() = activity

    companion object {
        private const val METHOD_CHANNEL = "oriongo/mount_bt"
        private const val EVENT_CHANNEL = "oriongo/mount_bt/rx"

        /** UUID estándar del perfil de puerto serie (SPP). */
        private val SPP_UUID: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        private const val DISCOVERY_WINDOW_MS = 12_000L

        private const val PERMISSION_REQUEST_CODE = 4731
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    private val mainHandler = Handler(Looper.getMainLooper())

    private var events: EventChannel.EventSink? = null
    private var socket: BluetoothSocket? = null
    private var output: OutputStream? = null
    private var reader: Thread? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val adapter: BluetoothAdapter?
        get() = BluetoothAdapter.getDefaultAdapter()

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isEnabled" -> result.success(adapter?.isEnabled == true)
            "requestPermissions" -> requestPermissions(result)
            "pairedDevices" -> result.success(pairedDevices())
            "discoverDevices" -> discoverDevices(result)
            "connect" -> connect(call.argument<String>("address"), result)
            "disconnect" -> {
                closeSocket()
                result.success(null)
            }
            "send" -> {
                val data = call.argument<String>("data")
                try {
                    output?.apply {
                        write("$data\n".toByteArray())
                        flush()
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("SEND_ERROR", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------- permisos

    /** Permisos que Android exige para emparejar y descubrir la montura. */
    private fun requiredPermissions(): List<String> = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> listOf(
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
        )
        else -> listOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }

        val missing = requiredPermissions().filterNot { hasPermission(it) }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }

        // Solo se admite una solicitud a la vez.
        pendingPermissionResult?.success(false)
        pendingPermissionResult = result
        activity.requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    /** Devuelve `true` si la respuesta corresponde a este plugin. */
    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false

        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }

        val pending = pendingPermissionResult
        pendingPermissionResult = null
        mainHandler.post { pending?.success(granted) }
        return true
    }

    private fun hasPermission(permission: String): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

    private fun hasConnectPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            hasPermission(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            true
        }

    private fun hasScanPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            hasPermission(Manifest.permission.BLUETOOTH_SCAN)
        } else {
            hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    // --------------------------------------------------------- dispositivos
    @SuppressLint("MissingPermission")
    private fun pairedDevices(): List<Map<String, Any>> {
        if (!hasConnectPermission()) return emptyList()
        val bonded = adapter?.bondedDevices ?: return emptyList()
        return bonded.map { device ->
            mapOf(
                "address" to device.address,
                "name" to (device.name ?: "Sin nombre"),
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun discoverDevices(result: MethodChannel.Result) {
        val bluetooth = adapter
        if (bluetooth == null || !hasScanPermission()) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        val found = linkedMapOf<String, Map<String, Any>>()

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_FOUND) return
                val address = intent
                    .getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                    ?.address ?: return

                found[address] = mapOf(
                    "address" to address,
                    "name" to (intent.getStringExtra(BluetoothDevice.EXTRA_NAME)
                        ?: "Dispositivo desconocido"),
                )
            }
        }

        context.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_FOUND))

        if (bluetooth.isDiscovering) bluetooth.cancelDiscovery()
        bluetooth.startDiscovery()

        thread(name = "oriongo-bt-discovery") {
            Thread.sleep(DISCOVERY_WINDOW_MS)
            try {
                if (bluetooth.isDiscovering) bluetooth.cancelDiscovery()
                context.unregisterReceiver(receiver)
            } catch (_: Exception) {
                // El receptor ya estaba liberado.
            }
            result.success(found.values.toList())
        }
    }

    // -------------------------------------------------------------- socket
    @SuppressLint("MissingPermission")
    private fun connect(address: String?, result: MethodChannel.Result) {
        if (address == null || !hasConnectPermission()) {
            result.error("NO_PERMISSION", "Falta el permiso de Bluetooth.", null)
            return
        }

        val device = try {
            adapter?.getRemoteDevice(address)
        } catch (error: IllegalArgumentException) {
            null
        }

        if (device == null) {
            result.error("NO_DEVICE", "La dirección $address no es válida.", null)
            return
        }

        thread(name = "oriongo-bt-connect") {
            try {
                closeSocket()

                val bluetoothSocket =
                    device.createRfcommSocketToServiceRecord(SPP_UUID)
                adapter?.cancelDiscovery()
                bluetoothSocket.connect()

                socket = bluetoothSocket
                output = bluetoothSocket.outputStream
                startReader(bluetoothSocket)

                mainHandler.post { result.success(null) }
            } catch (error: Exception) {
                closeSocket()
                mainHandler.post {
                    result.error("CONNECT_ERROR", error.message, null)
                }
            }
        }
    }

    private fun startReader(bluetoothSocket: BluetoothSocket) {
        reader = thread(name = "oriongo-bt-reader") {
            try {
                val buffer = BufferedReader(
                    InputStreamReader(bluetoothSocket.inputStream),
                )

                val pending = StringBuilder()
                val chunk = CharArray(256)

                while (true) {
                    val read = buffer.read(chunk)
                    if (read <= 0) break

                    pending.append(chunk, 0, read)

                    var index = pending.indexOf("\n")
                    while (index >= 0) {
                        val line = pending.substring(0, index).trim()
                        if (line.isNotEmpty()) {
                            mainHandler.post { events?.success(line) }
                        }
                        pending.delete(0, index + 1)
                        index = pending.indexOf("\n")
                    }
                }
            } catch (_: Exception) {
                // La conexión se cerró.
            } finally {
                closeSocket()
            }
        }
    }

    private fun closeSocket() {
        try {
            output?.close()
        } catch (_: Exception) {
        }
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        output = null
        socket = null
    }
}
