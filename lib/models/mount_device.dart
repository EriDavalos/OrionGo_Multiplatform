import 'dart:convert';

/// Estado de conexión de un dispositivo en la lista.
enum MountStatus { available, connecting, connected, noConnected }

extension MountStatusLabel on MountStatus {
  String get label => switch (this) {
        MountStatus.available => 'Disponible',
        MountStatus.connecting => 'Conectando...',
        MountStatus.connected => 'Conectado',
        MountStatus.noConnected => 'No se pudo conectar con este dispositivo',
      };
}

/// Dispositivo de montura (Bluetooth en Android, puerto serie en escritorio).
class MountDevice {
  MountDevice({
    required this.id,
    required this.name,
    required this.address,
    this.model,
    this.idDevice,
    this.isDefault = false,
  });

  final String id;
  final String name;

  /// En Android es la MAC; en escritorio el nombre del puerto (COM3).
  final String address;
  String? model;
  String? idDevice;
  bool isDefault;

  factory MountDevice.fromJson(Map<String, dynamic> json) => MountDevice(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Sin nombre').toString(),
        address: (json['address'] ?? '').toString(),
        model: json['model']?.toString(),
        idDevice: json['idDevice']?.toString(),
        isDefault: json['default'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'model': model,
        'idDevice': idDevice,
        'default': isDefault,
      };

  @override
  String toString() => 'MountDevice($name, $address)';

  static List<MountDevice> listFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MountDevice.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// Usuario conectado a la sala remota (mismo formato que envía el servidor).
class RemoteUser {
  const RemoteUser({
    required this.username,
    required this.userId,
    required this.posRA,
    required this.posDEC,
    required this.color,
    required this.admin,
  });

  final String username;
  final String userId;
  final double posRA;
  final double posDEC;
  final String color;
  final bool admin;

  factory RemoteUser.fromJson(Map<String, dynamic> json) => RemoteUser(
        username: (json['username'] ?? '').toString(),
        userId: (json['userId'] ?? '').toString(),
        posRA: (json['posRA'] as num?)?.toDouble() ?? 0,
        posDEC: (json['posDEC'] as num?)?.toDouble() ?? 90,
        color: (json['color'] ?? '#FFFFFF').toString(),
        admin: json['admin'] == true,
      );
}
