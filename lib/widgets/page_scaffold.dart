import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import 'panels.dart';

/// Contenedor estándar de una vista.
///
/// En teléfono muestra una barra superior con el botón de menú (como la app
/// móvil); en escritorio muestra un encabezado amplio con subtítulo y acciones,
/// y centra el contenido para que no se estire en pantallas grandes.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.onMenu,
    this.onBack,
    this.scrollable = true,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.background,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onMenu;
  final VoidCallback? onBack;
  final Widget child;
  final bool scrollable;
  final double maxWidth;
  final EdgeInsets padding;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final desktop = context.isDesktop;

    final content = ResponsiveContent(
      maxWidth: maxWidth,
      padding: padding,
      child: child,
    );

    return Container(
      color: background ?? AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop)
            ResponsiveContent(
              maxWidth: maxWidth,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: PageHeader(
                title: title,
                subtitle: subtitle,
                actions: actions,
                onBack: onBack,
              ),
            )
          else
            _MobileBar(
              title: title,
              actions: actions,
              onMenu: onMenu,
              onBack: onBack,
            ),
          Expanded(
            child: scrollable
                ? SingleChildScrollView(child: content)
                : content,
          ),
        ],
      ),
    );
  }
}

class _MobileBar extends StatelessWidget {
  const _MobileBar({
    required this.title,
    required this.actions,
    this.onMenu,
    this.onBack,
  });

  final String title;
  final List<Widget> actions;
  final VoidCallback? onMenu;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 6,
        bottom: 10,
        left: 4,
        right: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Volver',
            )
          else if (onMenu != null)
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Menú',
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
