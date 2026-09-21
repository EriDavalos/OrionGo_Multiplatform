#ifndef RUNNER_MOUNT_BLUETOOTH_CHANNEL_H_
#define RUNNER_MOUNT_BLUETOOTH_CHANNEL_H_

#include <memory>

// Canal de Bluetooth serial (SPP/RFCOMM) para Windows. Implementa el mismo
// contrato de MethodChannel ('oriongo/mount_bt') que el plugin de Android:
// isEnabled, requestPermissions, pairedDevices, discoverDevices, connect,
// disconnect y send; con el EventChannel 'oriongo/mount_bt/rx' para lo que
// llega de la montura.
//
// Este encabezado no incluye <windows.h> ni <winsock2.h>: los tipos nativos
// se manejan como opacos porque winsock2.h debe incluirse ANTES que
// windows.h (si windows.h llega primero arrastra winsock.h y el proyecto
// no compila). Toda la implementación vive en el .cpp.
class MountBluetoothChannel {
 public:
  // |messenger|: flutter::BinaryMessenger*; |window|: HWND de la ventana
  // runner. Se pasan como void* para mantener el encabezado limpio.
  MountBluetoothChannel(void* messenger, void* window);
  ~MountBluetoothChannel();

  MountBluetoothChannel(const MountBluetoothChannel&) = delete;
  MountBluetoothChannel& operator=(const MountBluetoothChannel&) = delete;

  // WM_APP + 1: mensaje de ventana para despachar al hilo de la plataforma
  // las tareas encoladas desde hilos de trabajo (respuestas diferidas y
  // líneas recibidas de la montura).
  static constexpr unsigned int kSignalMessage = 0x8001;

  // Se ejecuta en el hilo de la plataforma (desde MessageHandler).
  void DrainPending();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_MOUNT_BLUETOOTH_CHANNEL_H_
