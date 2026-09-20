import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/responsive.dart';
import 'core/theme.dart';
import 'pages/devices_page.dart';
import 'pages/home_page.dart';
import 'pages/location_page.dart';
import 'pages/logs_page.dart';
import 'pages/motor_settings_page.dart';
import 'pages/pair_page.dart';
import 'pages/remote_page.dart';
import 'pages/settings_page.dart';
import 'services/app_state.dart';
import 'widgets/app_menu.dart';
import 'widgets/dialogs.dart';
import 'widgets/search_modal.dart';

class OrionApp extends StatelessWidget {
  const OrionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrionGo Platform',
      debugShowCheckedModeBanner: false,
      theme: buildOrionTheme(),
      navigatorKey: Dialogs.navigatorKey,
      home: const AppShell(),
    );
  }
}

/// Estructura principal: barra lateral en escritorio, drawer en teléfono.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  AppSection _section = AppSection.home;
  AppSection? _tool;

  bool get _isDesktop => MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _select(AppSection section) {
    // La búsqueda es un modal en ambas plataformas (como el ModalController
    // de la app móvil), con conexión a la montura integrada.
    if (section == AppSection.search) {
      showSearchModal(context);
      return;
    }

    final isTool = toolDestinations.any((d) => d.section == section);

    if (!isTool) {
      setState(() {
        _section = section;
        _tool = null;
      });
      return;
    }

    if (_isDesktop) {
      setState(() => _tool = section);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.bg,
            body: SafeArea(child: _buildPage(section, isTool: true)),
          ),
        ),
      );
    }
  }

  void _closeTool() => setState(() => _tool = null);

  Widget _buildPage(AppSection section, {bool isTool = false}) {
    final onBack = isTool
        ? (_isDesktop ? _closeTool : () => Navigator.of(context).maybePop())
        : null;

    return switch (section) {
      AppSection.home => HomePage(
          onOpenTool: _select,
          onOpenDrawer: _isDesktop ? null : _openDrawer,
        ),
      AppSection.devices => DevicesPage(onMenu: _isDesktop ? null : _openDrawer),
      AppSection.remote => RemotePage(onMenu: _isDesktop ? null : _openDrawer),
      AppSection.motor => MotorSettingsPage(
          onMenu: _isDesktop ? null : _openDrawer,
        ),
      AppSection.settings => SettingsPage(
          onMenu: _isDesktop ? null : _openDrawer,
        ),
      AppSection.pair => PairPage(onBack: onBack),
      // La búsqueda se abre como modal desde _select(); este caso nunca se
      // alcanza, pero el switch debe ser exhaustivo.
      AppSection.search => const SizedBox.shrink(),
      AppSection.location => LocationPage(onBack: onBack),
      AppSection.logs => LogsPage(onBack: onBack),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      final collapsed = context.select<AppState, bool>(
        (state) => state.sidebarCollapsed,
      );

      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Row(
          children: [
            OrionSidebar(
              current: _section,
              activeTool: _tool,
              onSelect: _select,
              collapsed: collapsed,
              onToggle: () => context.read<AppState>().toggleSidebar(),
            ),
            Expanded(child: _buildPage(_tool ?? _section, isTool: _tool != null)),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: OrionDrawer(current: _section, onSelect: _select),
      resizeToAvoidBottomInset: true,
      body: _buildPage(_section),
    );
  }
}

/// Acceso al estado desde cualquier widget (azúcar sintáctico).
extension AppStateContext on BuildContext {
  AppState get app => read<AppState>();
}
