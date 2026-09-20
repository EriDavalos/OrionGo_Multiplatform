import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../models/mount_device.dart';
import 'mount_link.dart';

/// Conexión por puerto serie en computadora.
///
/// Los módulos Bluetooth que se emparejan en el sistema operativo exponen un
/// puerto serie (por ejemplo `COM5` en Windows o `/dev/rfcomm0` en Linux), así
/// que esta misma implementación cubre Bluetooth y USB.
class SerialMountLink implements MountLink {
  SerialMountLink({this.baudRate = 9600});

  int baudRate;

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _subscription;
  final StringBuffer _buffer = StringBuffer();
  String? _connectedAddress;

  final StreamController<String> _lines = StreamController<String>.broadcast();

  @override
  String get platformLabel => 'Puerto serie / Bluetooth';

  @override
  String get hint =>
      'Empareja la montura desde los ajustes de Bluetooth del sistema y '
      'selecciona el puerto serie que aparece (COM en Windows).';

  @override
  bool get isSupported => SerialPort.availablePorts.isNotEmpty || _port != null;

  @override
  bool get isConnected => _port?.isOpen ?? false;

  @override
  Stream<String> get incoming => _lines.stream;

  @override
  Future<void> requestPermissions() async {
    // El sistema operativo gestiona el emparejamiento; no hay permisos extra.
  }

  @override
  Future<List<MountDevice>> knownDevices() async => _ports();

  @override
  Future<List<MountDevice>> discoverDevices() async => _ports();

  List<MountDevice> _ports() {
    return SerialPort.availablePorts.map((name) {
      final port = SerialPort(name);
      String? description;
      try {
        description = port.description;
      } catch (_) {
        description = null;
      } finally {
        port.dispose();
      }

      final isBluetooth = (description ?? '').toLowerCase().contains('bluetooth');
      final label = description != null && description.isNotEmpty
          ? '$name · $description'
          : name;

      return MountDevice(
        id: name,
        name: label,
        address: name,
        model: isBluetooth ? 'Bluetooth' : 'Puerto serie',
      );
    }).toList()
      ..sort((a, b) => a.address.compareTo(b.address));
  }

  @override
  Future<void> connect(MountDevice device) async {
    await disconnect();

    final port = SerialPort(device.address);
    if (!port.openReadWrite()) {
      port.dispose();
      throw Exception('No se pudo abrir el puerto ${device.address}.');
    }

    final config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = 8
      ..stopBits = 1
      ..parity = SerialPortParity.none;
    port.config = config;
    port.flush();

    _port = port;
    _connectedAddress = device.address;

    _reader = SerialPortReader(port);
    _subscription = _reader!.stream.listen(
      _onData,
      onError: (Object error) {
        _lines.addError(error);
        _cleanup();
      },
      onDone: _cleanup,
    );
  }

  void _onData(Uint8List data) {
    _buffer.write(utf8.decode(data, allowMalformed: true));
    final content = _buffer.toString();
    final parts = content.split('\n');
    // La última parte puede ser una línea incompleta: se conserva en el buffer.
    _buffer
      ..clear()
      ..write(parts.removeLast());

    for (final line in parts) {
      final clean = line.trim();
      if (clean.isNotEmpty) _lines.add(clean);
    }
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _reader?.close();
    _reader = null;
    _cleanup();
  }

  void _cleanup() {
    try {
      if (_port?.isOpen ?? false) _port!.close();
    } catch (_) {
      // El puerto ya estaba cerrado.
    }
    _port?.dispose();
    _port = null;
    _connectedAddress = null;
  }

  @override
  Future<void> send(String command) async {
    final port = _port;
    if (port == null || !port.isOpen) {
      throw Exception('El puerto serie no está abierto.');
    }
    port.write(Uint8List.fromList(utf8.encode('$command\n')));
  }

  String? get connectedAddress => _connectedAddress;

  Future<void> dispose() async {
    await disconnect();
    await _lines.close();
  }
}
