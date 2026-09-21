import 'dart:io' show Platform;

import 'bluetooth_serial_link.dart';
import 'desktop_mount_link.dart';
import 'mount_link.dart';
import 'serial_link.dart';

/// Devuelve la conexión adecuada según la plataforma:
/// Android -> Bluetooth serial nativo.
/// Windows -> Bluetooth serial nativo (RFCOMM/SPP) + puertos serie, para
/// cubrir tanto la montura Bluetooth como adaptadores USB-serial.
/// Linux/macOS -> puerto serie (incluye /dev/rfcomm de Bluetooth emparejado).
MountLink? createMountLink({int baudRate = 9600}) {
  if (Platform.isAndroid) {
    return BluetoothSerialLink();
  }
  if (Platform.isWindows) {
    return DesktopMountLink(serialLink: SerialMountLink(baudRate: baudRate));
  }
  if (Platform.isLinux || Platform.isMacOS) {
    return SerialMountLink(baudRate: baudRate);
  }
  return null;
}
