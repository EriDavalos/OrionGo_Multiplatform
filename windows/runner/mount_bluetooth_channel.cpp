// ORDEN CRÍTICO: <winsock2.h> antes que <windows.h>; si windows.h llega
// primero arrastra winsock.h y el proyecto no compila.
#include <winsock2.h>

#include <bthsdpdef.h>
#include <bluetoothapis.h>
#include <windows.h>
#include <ws2bth.h>

#include "mount_bluetooth_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <deque>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <utility>

namespace {

// UUID del perfil de puerto serie (SPP), el mismo que usa la montura Orion y
// el plugin de Android. Al pasarlo en SOCKADDR_BTH::serviceClassId, Winsock
// resuelve el canal RFCOMM por SDP automáticamente.
const GUID kSppServiceClassUuid = {
    0x00001101,
    0x0000,
    0x1000,
    {0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB}};

bool EnsureWinsock() {
  static const bool started = []() {
    WSADATA data;
    return WSAStartup(MAKEWORD(2, 2), &data) == 0;
  }();
  return started;
}

BTH_ADDR ParseAddress(const std::string& address) {
  unsigned int b[6] = {};
  if (sscanf_s(address.c_str(), "%2x:%2x:%2x:%2x:%2x:%2x", &b[0], &b[1], &b[2],
               &b[3], &b[4], &b[5]) != 6) {
    return 0;
  }
  BTH_ADDR result = 0;
  for (int i = 0; i < 6; ++i) {
    result = (result << 8) | (b[i] & 0xFF);
  }
  return result;
}

std::string AddressToString(BTH_ADDR address) {
  char buffer[18];
  sprintf_s(buffer, sizeof(buffer), "%02X:%02X:%02X:%02X:%02X:%02X",
            (unsigned)((address >> 40) & 0xFF),
            (unsigned)((address >> 32) & 0xFF),
            (unsigned)((address >> 24) & 0xFF),
            (unsigned)((address >> 16) & 0xFF),
            (unsigned)((address >> 8) & 0xFF),
            (unsigned)(address & 0xFF));
  return buffer;
}

std::string Utf8(const WCHAR* wide) {
  if (wide == nullptr) return {};
  const int size =
      WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) return {};
  std::string result(size - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, result.data(), size, nullptr,
                      nullptr);
  return result;
}

flutter::EncodableValue DeviceMap(const std::string& address,
                                  const std::string& name) {
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("address"), flutter::EncodableValue(address)},
      {flutter::EncodableValue("name"), flutter::EncodableValue(name)},
  });
}

}  // namespace

struct MountBluetoothChannel::Impl {
  flutter::BinaryMessenger* messenger;
  HWND window;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> rx_sink;

  std::mutex pending_mutex;
  std::deque<std::function<void()>> pending;

  SOCKET socket = INVALID_SOCKET;
  std::thread reader;
  std::atomic<bool> connected{false};
  std::atomic<bool> discovery_running{false};

  void PostTask(std::function<void()> task) {
    {
      std::lock_guard<std::mutex> lock(pending_mutex);
      pending.push_back(std::move(task));
    }
    PostMessage(window, MountBluetoothChannel::kSignalMessage, 0, 0);
  }

  void DrainPending() {
    while (true) {
      std::function<void()> task;
      {
        std::lock_guard<std::mutex> lock(pending_mutex);
        if (pending.empty()) return;
        task = std::move(pending.front());
        pending.pop_front();
      }
      task();
    }
  }

  bool HasRadio() {
    BLUETOOTH_FIND_RADIO_PARAMS params = {sizeof(params)};
    HANDLE radio = nullptr;
    HBLUETOOTH_RADIO_FIND find = BluetoothFindFirstRadio(&params, &radio);
    if (find == nullptr) return false;
    BluetoothFindRadioClose(find);
    CloseHandle(radio);
    return true;
  }

  void HandlePairedDevices(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    EnsureWinsock();

    BLUETOOTH_FIND_RADIO_PARAMS radio_params = {sizeof(radio_params)};
    HANDLE radio = nullptr;
    HBLUETOOTH_RADIO_FIND radio_find =
        BluetoothFindFirstRadio(&radio_params, &radio);
    if (radio_find == nullptr) {
      result->Success(flutter::EncodableValue(flutter::EncodableList{}));
      return;
    }

    flutter::EncodableList devices;
    BLUETOOTH_DEVICE_SEARCH_PARAMS params = {sizeof(params)};
    params.fReturnAuthenticated = TRUE;
    params.fReturnRemembered = TRUE;
    params.fReturnUnknown = FALSE;
    params.fReturnConnected = TRUE;
    params.fIssueInquiry = FALSE;
    params.hRadio = radio;

    BLUETOOTH_DEVICE_INFO info = {sizeof(info)};
    HBLUETOOTH_DEVICE_FIND find = BluetoothFindFirstDevice(&params, &info);
    if (find != nullptr) {
      do {
        devices.push_back(
            DeviceMap(AddressToString(info.Address.ullLong), Utf8(info.szName)));
      } while (BluetoothFindNextDevice(find, &info));
      BluetoothFindDeviceClose(find);
    }

    BluetoothFindRadioClose(radio_find);
    CloseHandle(radio);
    result->Success(flutter::EncodableValue(std::move(devices)));
  }

  void HandleDiscoverDevices(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    EnsureWinsock();

    if (discovery_running.exchange(true)) {
      result->Success(flutter::EncodableValue(flutter::EncodableList{}));
      return;
    }

    // La búsqueda con inquiry bloquea ~12.8 s: se hace en un hilo aparte,
    // como en Android (DISCOVERY_WINDOW_MS).
    auto* raw_result = result.release();
    std::thread([this, raw_result]() {
      flutter::EncodableList devices;

      BLUETOOTH_FIND_RADIO_PARAMS radio_params = {sizeof(radio_params)};
      HANDLE radio = nullptr;
      HBLUETOOTH_RADIO_FIND radio_find =
          BluetoothFindFirstRadio(&radio_params, &radio);
      if (radio_find != nullptr) {
        BLUETOOTH_DEVICE_SEARCH_PARAMS params = {sizeof(params)};
        params.fReturnAuthenticated = TRUE;
        params.fReturnRemembered = TRUE;
        params.fReturnUnknown = TRUE;
        params.fReturnConnected = TRUE;
        params.fIssueInquiry = TRUE;
        params.cTimeoutMultiplier = 10;
        params.hRadio = radio;

        BLUETOOTH_DEVICE_INFO info = {sizeof(info)};
        HBLUETOOTH_DEVICE_FIND find = BluetoothFindFirstDevice(&params, &info);
        if (find != nullptr) {
          do {
            devices.push_back(DeviceMap(AddressToString(info.Address.ullLong),
                                        Utf8(info.szName)));
          } while (BluetoothFindNextDevice(find, &info));
          BluetoothFindDeviceClose(find);
        }
        BluetoothFindRadioClose(radio_find);
        CloseHandle(radio);
      }

      PostTask([this, raw_result, devices = std::move(devices)]() mutable {
        discovery_running = false;
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
            result(raw_result);
        result->Success(flutter::EncodableValue(std::move(devices)));
      });
    }).detach();
  }

  void HandleConnect(
      const std::string& address,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    EnsureWinsock();

    const BTH_ADDR bt_addr = ParseAddress(address);
    if (bt_addr == 0) {
      result->Error("NO_DEVICE", "Dirección Bluetooth inválida: " + address);
      return;
    }

    auto* raw_result = result.release();
    std::thread([this, bt_addr, raw_result]() {
      CloseSocket();

      SOCKET sock = ::socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
      if (sock == INVALID_SOCKET) {
        PostTask([raw_result]() {
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result(raw_result);
          result->Error("CONNECT_ERROR",
                        "No se pudo crear el socket Bluetooth.");
        });
        return;
      }

      SOCKADDR_BTH remote = {};
      remote.addressFamily = AF_BTH;
      remote.btAddr = bt_addr;
      remote.serviceClassId = kSppServiceClassUuid;
      remote.port = 0;

      if (connect(sock, reinterpret_cast<SOCKADDR*>(&remote),
                  sizeof(remote)) == SOCKET_ERROR) {
        const int error = WSAGetLastError();
        closesocket(sock);
        PostTask([raw_result, error]() {
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result(raw_result);
          result->Error("CONNECT_ERROR",
                        "No se pudo conectar con la montura (WSA " +
                            std::to_string(error) + ").");
        });
        return;
      }

      this->socket = sock;
      connected = true;
      StartReader(sock);

      PostTask([raw_result]() {
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
            result(raw_result);
        result->Success(nullptr);
      });
    }).detach();
  }

  void StartReader(SOCKET sock) {
    reader = std::thread([this, sock]() {
      std::string pending;
      char buffer[1024];

      while (connected) {
        const int received = recv(sock, buffer, sizeof(buffer), 0);
        if (received <= 0) break;
        pending.append(buffer, received);

        size_t index;
        while ((index = pending.find('\n')) != std::string::npos) {
          std::string line = pending.substr(0, index);
          pending.erase(0, index + 1);

          // Recorte como en Android (trim).
          const size_t first = line.find_first_not_of(" \t\r\n");
          if (first == std::string::npos) continue;
          const size_t last = line.find_last_not_of(" \t\r\n");
          line = line.substr(first, last - first + 1);
          if (line.empty()) continue;

          PostTask([this, line]() {
            if (rx_sink != nullptr) {
              rx_sink->Success(flutter::EncodableValue(line));
            }
          });
        }
      }

      PostTask([this]() {
        connected = false;
        if (socket != INVALID_SOCKET) {
          closesocket(socket);
          socket = INVALID_SOCKET;
        }
      });
    });
  }

  void HandleSend(
      const std::string& data,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (!connected || socket == INVALID_SOCKET) {
      result->Error("SEND_ERROR", "No hay conexión Bluetooth activa.");
      return;
    }

    const std::string payload = data + "\n";
    if (::send(socket, payload.c_str(), static_cast<int>(payload.size()),
               0) == SOCKET_ERROR) {
      result->Error("SEND_ERROR", "No se pudo enviar el comando.");
      return;
    }
    result->Success(nullptr);
  }

  void CloseSocket() {
    connected = false;
    if (socket != INVALID_SOCKET) {
      closesocket(socket);
      socket = INVALID_SOCKET;
    }
    if (reader.joinable()) {
      reader.join();
    }
  }

  void HandleMethodCallRouting(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string& method = call.method_name();

    if (method == "isEnabled") {
      result->Success(flutter::EncodableValue(HasRadio()));
    } else if (method == "requestPermissions") {
      // Windows no pide permisos en tiempo de ejecución para Bluetooth
      // clásico.
      result->Success(flutter::EncodableValue(true));
    } else if (method == "pairedDevices") {
      HandlePairedDevices(std::move(result));
    } else if (method == "discoverDevices") {
      HandleDiscoverDevices(std::move(result));
    } else if (method == "connect") {
      std::string address;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("address"));
        if (it != args->end()) {
          if (const auto* value = std::get_if<std::string>(&it->second)) {
            address = *value;
          }
        }
      }
      HandleConnect(address, std::move(result));
    } else if (method == "disconnect") {
      CloseSocket();
      result->Success(nullptr);
    } else if (method == "send") {
      std::string data;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("data"));
        if (it != args->end()) {
          if (const auto* value = std::get_if<std::string>(&it->second)) {
            data = *value;
          }
        }
      }
      HandleSend(data, std::move(result));
    } else {
      result->NotImplemented();
    }
  }
};

MountBluetoothChannel::MountBluetoothChannel(void* messenger, void* window)
    : impl_(new Impl()) {
  impl_->messenger = static_cast<flutter::BinaryMessenger*>(messenger);
  impl_->window = static_cast<HWND>(window);
  EnsureWinsock();

  impl_->method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          impl_->messenger, "oriongo/mount_bt",
          &flutter::StandardMethodCodec::GetInstance());
  impl_->method_channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        impl_->HandleMethodCallRouting(call, std::move(result));
      });

  impl_->event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          impl_->messenger, "oriongo/mount_bt/rx",
          &flutter::StandardMethodCodec::GetInstance());
  impl_->event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue* args,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                     sink) {
            impl_->rx_sink = std::move(sink);
            return nullptr;
          },
          [this](const flutter::EncodableValue* args) {
            impl_->rx_sink = nullptr;
            return nullptr;
          }));
}

MountBluetoothChannel::~MountBluetoothChannel() {
  impl_->CloseSocket();
  impl_->method_channel->SetMethodCallHandler(nullptr);
  impl_->event_channel->SetStreamHandler(nullptr);
}

void MountBluetoothChannel::DrainPending() {
  impl_->DrainPending();
}
