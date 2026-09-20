import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reemplazo de settings.service.ts usando shared_preferences.
class SettingsService {
  static const _defaults = <String, dynamic>{
    'username': 'Invitado',
    'userId': 'NA',
    'isNew': true,
    'devicesRegistered': <dynamic>[],
    'isAzimuthalGrid': true,
    'isEquatorialGrid': true,
    'sidebarCollapsed': false,
    'baudRate': 9600,
  };

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> initDefaults() async {
    final p = await _p;
    for (final entry in _defaults.entries) {
      if (!p.containsKey(entry.key)) {
        await p.setString(entry.key, jsonEncode(entry.value));
      }
    }
  }

  Future<T> get<T>(String key) async {
    final p = await _p;
    final raw = p.getString(key);
    if (raw != null) {
      try {
        return jsonDecode(raw) as T;
      } catch (_) {
        return raw as T;
      }
    }
    return _defaults[key] as T;
  }

  Future<void> set(String key, Object? value) async {
    final p = await _p;
    await p.setString(key, jsonEncode(value));
  }

  Future<void> reset() async {
    for (final entry in _defaults.entries) {
      await set(entry.key, entry.value);
    }
  }
}
