import 'dart:async';

import 'package:flutter/services.dart';

import '../models/mount_device.dart';
import 'mount_link.dart';

/// Bluetooth serial clásico (SPP/RFCOMM) en Android.
///
/// Se implementa con un MethodChannel propio para no depender de plugins
/// abandonados: el lado nativo usa BluetoothSocket con el UUID SPP estándar.
class AndroidMountLink implements MountLink {
  AndroidMountLink();

  static const MethodChannel _channel = MethodChannel('oriongo/mount_bt');
  static const EventChannel _rxChannel = EventChannel('oriongo/mount_bt/rx');

  bool _connected = false;

  @override
  String get platformLabel => 'Bluetooth';

  @override
  String get hint =>
      'Empareja la montura desde los ajustes de Bluetooth de Android y '
      'selecciónala aquí.';

  @override
  bool get isSupported => true;

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get incoming => _rxChannel
      .receiveBroadcastStream()
      .map((event) => event.toString().trim())
      .where((line) => line.isNotEmpty);

  @override
  Future<void> sendPermission() async {
    // El lado nativo pide los permisos de Android 12+ (BLUETOOTH_CONNECT y
    // BLUETOOTH_SCAN) o ACCESS_FINE_LOCATION en versiones previas.
    final granted = await _channel.invokeMethod<bool>('requestPermissions');
    if (granted != true) {
      throw Exception(
        'Se necesitan permisos de Bluetooth y ubicación para conectar la montura.',
      );
    }
  }

  @override
  Future<List<MountDevice>> listPairedDevices() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('pairedDevices');
    return _map(raw);
  }

  @override
  Future<List<MountDevice>> discoverUnpairedDevices() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('discoverDevices');
    return _map(raw);
  }

  List<MountDevice> _map(List<dynamic>? raw) {
    if (raw == null) return [];
    return raw.whereType<Map<dynamic, dynamic>>().map((item) {
      final map = item.map((key, value) => MapEntry('$key', value));
      return MountDevice(
        id: map['address']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Dispositivo desconocido',
        address: map['address']?.toString() ?? '',
        model: map['model']?.toString(),
        idDevice: map['idDevice']?.toString(),
      );
    }).where((device) => device.address.isNotEmpty).toList();
  }

  @override
  Future<void> connect(MountDevice device) async {
    await _channel.invokeMethod<void>('connect', {'address': device.address});
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
    _connected = false;
  }

  @override
  Future<void> sendMessage(String command) async {
    await _channel.invokeMethod<void>('send', {'data': command});
  }
}
