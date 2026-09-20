import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/app_state.dart';
import '../widgets/console_view.dart';
import '../widgets/page_scaffold.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return PageScaffold(
      title: 'Consolas',
      subtitle: 'Tramas enviadas y recibidas, y actividad del servidor remoto.',
      onBack: widget.onBack,
      scrollable: false,
      maxWidth: 1000,
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(text: 'Montura'),
              Tab(text: 'Servidor'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ConsoleView(lines: state.logDeviceList, height: double.infinity),
                ConsoleView(lines: state.logServerList, height: double.infinity),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
