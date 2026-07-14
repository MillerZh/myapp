import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/stock.dart';
import 'app_repositories.dart';
import 'monitor_service.dart';
import 'notification_service.dart';
import 'stock_api_service.dart';

const backgroundMonitorTask = 'com.example.stock.background.monitor';

@pragma('vm:entry-point')
void stockBackgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final settingsRepository = SettingsRepository();
      final settings = await settingsRepository.load();
      if (!settings.monitor.enabled ||
          settings.dataSource != StockDataSource.eastmoney) {
        return true;
      }
      final portfolioRepository = PortfolioRepository();
      final portfolio = await portfolioRepository.load();
      final targets = <WatchStock>[
        if (settings.monitor.monitorHoldings)
          ...portfolio.holdings.map(
            (holding) => WatchStock(
              code: holding.code,
              name: holding.name,
              sector: holding.sector,
            ),
          ),
        if (settings.monitor.monitorWatchlist) ...portfolio.watchlist,
      ];
      final unique = <String, WatchStock>{
        for (final stock in targets) stock.code: stock,
      }.values.toList();
      final api = StockApiRouter(
        StockApiConfig(source: StockDataSource.eastmoney),
      );
      final signalRepository = SignalRepository();
      final notification = NotificationService.instance;
      final monitor = IntradayMonitorService(api: api);
      monitor.configure(
        settings: settings.monitor.copyWith(enabled: false),
        targetsProvider: () => unique,
        onSignals: (signals) async {
          final current = await signalRepository.load();
          final saved = await signalRepository.appendDeduplicated(
            current,
            signals,
            cooldownMinutes: settings.monitor.cooldownMinutes,
          );
          final newIds = signals.map((signal) => signal.id).toSet();
          if (settings.notificationsEnabled) {
            for (final signal in saved.where(
              (item) =>
                  newIds.contains(item.id) &&
                  item.score >= settings.monitor.minimumSignalScore,
            )) {
              await notification.showSignal(signal);
            }
          }
        },
      );
      await monitor.checkNow(force: false);
      monitor.dispose();
      return true;
    } catch (_) {
      return false;
    }
  });
}

class BackgroundTaskService {
  static Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    await Workmanager().initialize(stockBackgroundCallbackDispatcher);
  }

  static Future<void> syncRegistration({required bool enabled}) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    if (!enabled) {
      await Workmanager().cancelByUniqueName(backgroundMonitorTask);
      return;
    }
    await Workmanager().registerPeriodicTask(
      backgroundMonitorTask,
      backgroundMonitorTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }
}
