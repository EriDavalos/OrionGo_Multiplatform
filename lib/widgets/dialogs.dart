import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Diálogos y avisos usados desde servicios (equivale a AlertController /
/// ToastController de Ionic, pero adaptado a teléfono y escritorio).
class Dialogs {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get _nav => navigatorKey.currentState;

  static void toast(String message) {
    final ctx = _nav?.overlay?.context;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  static Future<void> message(String title, String body) async {
    final ctx = _nav?.context;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  static Future<void> error(String body) =>
      message('¡Hay un problema!', body);

  static Future<bool> confirm(String title, String body) async {
    final ctx = _nav?.context;
    if (ctx == null) return false;
    final result = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
