import 'dart:io' show Platform;

import 'android_bt_link.dart';
import 'mount_link.dart';
import 'serial_link.dart';

/// Devuelve la conexión adecuada según la plataforma:
/// Android -> Bluetooth serial; Windows/Linux/macOS -> puerto serie (incluye
/// los dispositivos Bluetooth emparejados en el sistema operativo).
MountLink? createMountLink({int baudRate = 9600}) {
  if (Platform.isAndroid || Platform.isIOS) {
    return AndroidMountLink();
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return SerialMountLink(baudRate: baudRate);
  }
  return null;
}
