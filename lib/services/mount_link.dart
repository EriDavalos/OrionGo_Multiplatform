import '../models/mount_device.dart';

/// Contrato de la conexión con la montura Orion.
///
/// Android -> Bluetooth serial clásico (RFCOMM/SPP).
/// Escritorio -> puerto serie; los dispositivos Bluetooth SPP emparejados en el
/// sistema operativo aparecen como puertos COM (Windows) o /dev/rfcomm (Linux).
abstract class MountLink {
  /// Nombre corto del medio de conexión, para la interfaz.
  String get platformLabel;

  /// Texto de ayuda mostrado en la pantalla de emparejamiento.
  String get hint;

  /// `false` cuando la plataforma no soporta ninguna conexión directa.
  bool get isSupported;

  /// Permisos de Bluetooth (Android 12+). Nombre de bluetooth.service.ts.
  Future<void> sendPermission();

  /// Dispositivos ya conocidos: emparejados en Android, puertos ya abiertos
  /// en escritorio (portado de listPairedDevices()).
  Future<List<MountDevice>> listPairedDevices();

  /// Dispositivos nuevos: búsqueda Bluetooth o lista completa de puertos
  /// (portado de discoverUnpairedDevices()).
  Future<List<MountDevice>> discoverUnpairedDevices();

  bool get isConnected;

  Future<void> connect(MountDevice device);

  Future<void> disconnect();

  /// Envía `command` terminado en salto de línea (portado de sendMessage()).
  Future<void> sendMessage(String command);

  /// Líneas recibidas desde la montura, ya recortadas.
  Stream<String> get incoming;
}
