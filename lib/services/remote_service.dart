import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/mount_device.dart';
import '../widgets/dialogs.dart';
import 'app_state.dart';

/// Modo remoto (puerto de websocket.service.ts).
/// Permite que un administrador comparta su montura y que otros usuarios
/// observen o soliciten moverla.
class RemoteService {
  static const String server = 'oriongo.ddns.net';
  static const int port = 443;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _updateTimer;
  AppState? _state;

  /// Códigos de estado mostrados en la pantalla (igual que en Ionic).
  int notMode = 0;
  String firstId = '';

  bool get connected => _channel != null;

  String _link(String idDevice, String username, bool isAdmin, AppState state) {
    final user = '$username${state.userId}';
    return 'wss://$server:$port?id=$idDevice&username=$user'
        '&admin=$isAdmin&userId=${state.userId}&name=$username';
  }

  Future<void> connectWebSocket(
    AppState state,
    String idDevice, {
    required String username,
    bool isAdmin = false,
  }) async {
    _state = state;

    state.isAdmin = isAdmin;
    state.setUserColor();

    await disconnectWebSocket(silent: true);

    final channel = WebSocketChannel.connect(
      Uri.parse(_link(idDevice, username, isAdmin, state)),
    );
    _channel = channel;

    try {
      await channel.ready;
    } catch (error) {
      _channel = null;
      _reset(state);
      state.sendLogServer('No se pudo conectar al servidor: $error');
      rethrow;
    }

    firstId = idDevice;
    state.isAdminConnected = true;
    state.isServerConnected = true;
    state.sendLogServer('Se ha establecido la conexión en $server');

    if (state.isRemote && state.isAdmin) initUpdateAdmin(state);

    _subscription = channel.stream.listen(
      (event) => _onMessage(state, event),
      onError: (Object error) {
        state.sendLogServer('Error de conexión: $error');
        _reset(state);
      },
      onDone: () {
        state.sendLogServer('Se ha cerrado la conexión en $server');
        _reset(state);
      },
    );
  }

  void _onMessage(AppState state, dynamic event) {
    late final Map<String, dynamic> messages;
    try {
      messages = jsonDecode(event.toString()) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final action = messages['action'];

    switch (action) {
      case 'userList':
        final users = (messages['usersList'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(RemoteUser.fromJson)
            .toList();
        final admins = users.where((u) => u.admin).toList();
        state.isAdminConnected = admins.isNotEmpty;

        if (!state.isAdminConnected) {
          disconnectWebSocket(silent: true);
          Dialogs.message(
            'Has sido expulsado de la sala',
            'No hay ningún administrador dentro de la sala.',
          );
          notMode = 1;
        } else if (state.isAdmin) {
          final me = '${state.username}${state.userId}';
          final admin = admins.first;
          if (me == '${admin.username}${admin.userId}') {
            disconnectWebSocket(silent: true);
            Dialogs.message('Te han expulsado de la sala',
                'Ya existe un administrador.');
            notMode = 1;
          }
        }

        notMode = state.isAdminConnected ? 0 : (notMode == 4 ? 4 : 1);
        break;

      case 'userDisconnected':
        state.sendLogServer('${messages['user']} se ha desconectado de la sala');
        break;

      case 'userConnected':
        state.sendLogServer('${messages['user']} se ha conectado en la sala');
        break;

      case 'remoteControl':
        final code = messages['codeDevice'];
        if (state.isInitServer && state.isRemote && state.codeDeviceC == code) {
          _askRemoteControl(state, messages);
        } else if (state.codeDeviceC != code) {
          send({
            'action': 'remoteControlResponseDenied',
            'user': messages['user'],
            'codeDevice': state.codeDevice,
          });
        }
        break;

      case 'userData':
        state.usersData = (messages['userData'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(RemoteUser.fromJson)
            .toList();

        final deviceData = messages['deviceData'];
        if (deviceData is Map<String, dynamic> && !state.isAdmin) {
          final dt = DateTime.tryParse(deviceData['dtNow']?.toString() ?? '');
          if (dt != null) state.dtNow = dt;
          state.angleC1 = _num(deviceData['angleC1']);
          state.angleC2 = _num(deviceData['angleC2']);
          state.deviceConnectedAdmin = deviceData['deviceConnectedAdmin'] == true;
          state.nameDeviceConnectedAdmin =
              deviceData['nameDeviceConnectedAdmin']?.toString() ?? 'No conectado';
        }
        break;

      case 'joke':
        Dialogs.message('Oops, parece que has sido hackeado',
            'Dame tu dinero, guapo. O tal vez un beso...');
        break;

      case 'goto':
        state.goto(
          RAP: _num(messages['RA']),
          DECP: _num(messages['DEC']),
          isUser: true,
        );
        break;
    }

    if (messages['user'] == state.username) {
      if (action == 'remoteControlResponseAllowed') {
        notMode = 3;
        state.isOnline = true;
        initUpdate(state);
        Dialogs.toast('${state.idDevice} ha permitido su solicitud.');
      } else if (action == 'remoteControlResponseDenied') {
        notMode = 2;
        stopUpdate();
        Dialogs.toast('${state.idDevice} ha rechazado su solicitud.');
      }
    }
  }

  Future<void> _askRemoteControl(AppState state, Map<String, dynamic> messages) async {
    final allowed = await Dialogs.confirm(
      '¿Desea permitir este usuario?',
      'El usuario ${messages['user']} quiere entrar a su dispositivo; esto hará '
          'que pueda ver hacia dónde mira.',
    );

    send({
      'action': allowed
          ? 'remoteControlResponseAllowed'
          : 'remoteControlResponseDenied',
      'user': messages['user'],
      'codeDevice': state.codeDevice,
    });
  }

  static double _num(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  /// Envía el estado del observador (vista de usuario).
  void initUpdate(AppState state) {
    stopUpdate();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      send({
        'action': 'setData',
        'username': '${state.username}${state.userId}',
        'isOnline': state.isOnline,
        'posRA': state.touchedRA,
        'posDEC': state.touchedDEC,
        'color': _hex(state.color.toARGB32()),
      });
    });
  }

  /// Envía el estado del dispositivo (vista de administrador).
  void initUpdateAdmin(AppState state) {
    stopUpdate();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      send({
        'action': 'setData',
        'username': '${state.username}${state.userId}',
        'posRA': state.touchedRA,
        'posDEC': state.touchedDEC,
        'color': _hex(state.color.toARGB32()),
        'angleC1': state.angleC1,
        'angleC2': state.angleC2,
        'latitude': state.latitude,
        'longitude': state.longitude,
        'deviceConnectedAdmin': state.deviceConnected != null,
        'nameDeviceConnectedAdmin':
            state.deviceConnected?.name ?? 'No conectado',
        'dtNow': state.dtNow.toIso8601String(),
      });
    });
  }

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  void stopUpdate() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void send(Map<String, dynamic> payload) {
    final raws = _channel?.sink;
    if (raws == null) return;
    raws.add(jsonEncode(payload));
  }

  Future<void> disconnectWebSocket({bool silent = false}) async {
    stopUpdate();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;

    final state = _state;
    if (state != null && !silent) _reset(state);
  }

  void _reset(AppState state) {
    state.isServerConnected = false;
    state.isAdminConnected = false;
    state.isOnline = false;
    state.isAdmin = false;
    state.color = const Color(0xFFFFFFFF);
    firstId = '';
    state.usersData = [];
    stopUpdate();
  }
}
