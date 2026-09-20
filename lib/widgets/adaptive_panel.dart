import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';

/// En teléfono se comporta como las hojas inferiores de la app móvil; en
/// escritorio abre un diálogo centrado, más cómodo con teclado y ratón.
Future<void> showAdaptivePanel(
  BuildContext context, {
  required String title,
  required Widget child,
  double maxWidth = 720,
  bool scrollable = true,
}) {
  final desktop = context.isDesktop;

  if (desktop) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PanelHeader(title: title, onClose: () => Navigator.pop(context)),
              Flexible(
                child: scrollable
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: child,
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: child,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            _PanelHeader(title: title, onClose: () => Navigator.pop(context)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}
