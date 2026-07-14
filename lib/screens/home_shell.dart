import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'disciplines_screen.dart';
import 'holdings_screen.dart';
import 'settings_screen.dart';
import 'signals_screen.dart';
import 'watchlist_screen.dart';
import 'stock_detail_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 1;
  StreamSubscription<String>? _notificationSubscription;

  static const _pages = [
    HoldingsScreen(),
    SignalsScreen(),
    WatchlistScreen(),
    DisciplinesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationSubscription = NotificationService.instance.payloads.listen(
      _handleNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().load().then((_) {
        if (mounted) context.read<AppState>().scanSignals();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final appState = context.read<AppState>();
      appState.refreshQuotes();
      if (appState.monitor.isWithinWindow) {
        appState.monitor.checkNow(force: true);
      }
    }
  }

  void _handleNotification(String payload) {
    if (!mounted || !payload.startsWith('stock:')) return;
    final code = payload.substring('stock:'.length);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StockDetailScreen(code: code)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '持仓',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(
              Icons.notifications_active,
              color: AppTheme.accent,
            ),
            label: '信号',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: '自选',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '纪律',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
