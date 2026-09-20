package com.oriongo.platform

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var mountBluetooth: MountBluetoothPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal de Bluetooth serial (SPP) para la montura Orion.
        mountBluetooth =
            MountBluetoothPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        // El resultado se entrega al canal de Bluetooth si lo pidió él.
        mountBluetooth?.onRequestPermissionsResult(requestCode, grantResults)
    }
}
