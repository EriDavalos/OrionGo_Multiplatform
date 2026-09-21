import 'dart:async';

import '../models/mount_device.dart';
import 'bluetooth_serial_link.dart';
import 'mount_link.dart';
import 'serial_link.dart';

/// Enlace de escritorio (Windows/Linux/macOS): combina Bluetooth serial
/// clásico con los puertos serie del sistema.
///
/// - Direcciones tipo MAC (`AB:CD:EF:12:34:56`) -> socket RFCOMM/SPP nativo,
///   así el Bluetooth de la computadora se conecta a la montura sin depender
///   de los puertos COM que crea Windows al emparejar.
/// - Puertos (`COM5`, `/dev/ttyUSB0`, `/dev/rfcomm0`) -> puerto serie, para
///   adaptadores USB-serial.
class DesktopMountLink implements MountLink {
  DesktopMountLink({required SerialMountLink serialLink})
      : _serial = serialLink;

  final BluetoothSerialLink _bt = BluetoothSerialLink();
  final SerialMountLink _serial;

  /// Enlace actualmente conectado (para despachar envíos y desconexión).
  MountLink? _active;

  static final RegExp _macPattern =
      RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');

  bool _isBluetooth(String address) => _macPattern.hasMatch(address.trim());

  @override
  String get platformLabel => 'Bluetooth / Puerto serie';

  @override
  String get hint =>
      'Empareja la montura con el Bluetooth de Windows y selecciónala, o '
      'conecta un adaptador USB-serial y elige su puerto.';

  @override
  bool get isSupported => _bt.isSupported || _serial.isSupported;

  @override
  bool get isConnected => _active?.isConnected ?? false;

  @override
  Stream<String> get incoming {
    late final StreamController<String> controller;
    final subs = <StreamSubscription<String>>[];

    controller = StreamController<String>.broadcast(
      onListen: () {
        subs.add(_bt.incoming.listen(controller.add));
        subs.add(_serial.incoming.listen(controller.add));
      },
      onCancel: () {
        for (final sub in subs) {
          sub.cancel();
        }
        subs.clear();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> sendPermission() async {
    try {
      await _bt.sendPermission();
    } catch (_) {
      // En escritorio no hay permisos en tiempo de ejecución.
    }
    await _serial.sendPermission();
  }

  @override
  Future<List<MountDevice>> listPairedDevices() async {
    final devices = <String, MountDevice>{};
    try {
      for (final device in await _bt.listPairedDevices()) {
        devices[device.address] = device;
      }
    } catch (_) {
      // Sin adaptador Bluetooth o radio apagada: solo quedan los puertos.
    }
    for (final device in await _serial.listPairedDevices()) {
      devices.putIfAbsent(device.address, () => device);
    }
    return devices.values.toList();
  }

  @override
  Future<List<MountDevice>> discoverUnpairedDevices() async {
    final devices = <String, MountDevice>{};
    try {
      for (final device in await _bt.discoverUnpairedDevices()) {
        devices[device.address] = device;
      }
    } catch (_) {
      // Sin adaptador Bluetooth: solo quedan los puertos.
    }
    for (final device in await _serial.discoverUnpairedDevices()) {
      devices.putIfAbsent(device.address, () => device);
    }
    return devices.values.toList();
  }

  @override
  Future<void> connect(MountDevice device) async {
    final link = _isBluetooth(device.address) ? _bt : _serial;
    await link.connect(device);
    _active = link;
  }

  @override
  Future<void> disconnect() => _active?.disconnect() ?? Future.value();

  @override
  Future<void> sendMessage(String command) async {
    final link = _active;
    if (link == null || !link.isConnected) {
      throw Exception('No hay conexión activa con la montura.');
    }
    await link.sendMessage(command);
  }
}
