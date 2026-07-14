import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/market_data.dart';
import '../models/signal.dart';
import '../models/stock.dart';
import 'stock_api_service.dart';

typedef MonitorTargetsProvider = List<WatchStock> Function();
typedef MonitorSignalsCallback =
    Future<void> Function(List<TradeSignal> signals);

class IntradayMonitorService extends ChangeNotifier {
  IntradayMonitorService({required this.api});

  final StockApiService api;
  Timer? _timer;
  MonitorSettings _settings = const MonitorSettings();
  MonitorTargetsProvider? _targetsProvider;
  MonitorSignalsCallback? _onSignals;

  bool isRunning = false;
  bool isChecking = false;
  DateTime? lastCheckedAt;
  String? lastError;
  String? lastDataSource;
  int todayTriggerCount = 0;

  bool get isWithinWindow => _isWithinWindow(DateTime.now());

  void configure({
    required MonitorSettings settings,
    required MonitorTargetsProvider targetsProvider,
    required MonitorSignalsCallback onSignals,
  }) {
    _settings = settings;
    _targetsProvider = targetsProvider;
    _onSignals = onSignals;
    if (settings.enabled) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    _timer?.cancel();
    isRunning = true;
    _timer = Timer.periodic(
      Duration(seconds: _settings.pollSeconds.clamp(30, 300)),
      (_) {
        if (_isWithinWindow(DateTime.now())) checkNow();
      },
    );
    notifyListeners();
    if (_isWithinWindow(DateTime.now())) checkNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    isRunning = false;
    notifyListeners();
  }

  Future<List<TradeSignal>> checkNow({bool force = false}) async {
    if (isChecking) return const [];
    if (!force && !_isWithinWindow(DateTime.now())) return const [];
    final targets = _targetsProvider?.call() ?? const [];
    if (targets.isEmpty) return const [];

    isChecking = true;
    lastError = null;
    notifyListeners();
    final signals = <TradeSignal>[];
    try {
      for (var start = 0; start < targets.length; start += 4) {
        final batch = targets.sublist(
          start,
          math.min(start + 4, targets.length),
        );
        final results = await Future.wait(
          batch.map((stock) async {
            final result = await api.fetchIntraday(stock.code);
            lastDataSource = result.meta.sourceLabel;
            return _evaluate(stock, result);
          }),
        );
        signals.addAll(results.expand((items) => items));
      }
      lastCheckedAt = DateTime.now();
      todayTriggerCount += signals.length;
      if (signals.isNotEmpty) await _onSignals?.call(signals);
      return signals;
    } catch (error) {
      lastError = error.toString();
      return const [];
    } finally {
      isChecking = false;
      notifyListeners();
    }
  }

  List<TradeSignal> _evaluate(
    WatchStock stock,
    MarketDataResult<IntradaySnapshot> result,
  ) {
    final snapshot = result.data;
    if (snapshot.bars.length < 2 || snapshot.preClose <= 0) return const [];
    final date = snapshot.bars.last.date;
    final dayBars = snapshot.bars
        .where(
          (bar) =>
              bar.date.year == date.year &&
              bar.date.month == date.month &&
              bar.date.day == date.day &&
              bar.date.hour == 9 &&
              bar.date.minute >= 30 &&
              bar.date.minute <= 30 + _settings.windowEndMinute,
        )
        .toList();
    if (dayBars.length < 2) return const [];

    final first = dayBars.first;
    final last = dayBars.last;
    final maxHigh = dayBars.map((bar) => bar.high).reduce(math.max);
    final gap = (first.open - snapshot.preClose) / snapshot.preClose * 100;
    final surge = (maxHigh - first.open) / first.open * 100;
    final pullback = maxHigh == 0 ? 0 : (maxHigh - last.close) / maxHigh * 100;
    final avgVolume =
        dayBars
            .take(dayBars.length - 1)
            .map((bar) => bar.volume)
            .fold<double>(0, (sum, value) => sum + value) /
        math.max(1, dayBars.length - 1);
    final relativeVolume = avgVolume == 0 ? 0 : dayBars.last.volume / avgVolume;

    if (gap < _settings.gapPercent) return const [];
    final reasons = <String>[
      '跳空${gap.toStringAsFixed(1)}%',
      '窗口内冲高${surge.toStringAsFixed(1)}%',
      '高点回落${pullback.toStringAsFixed(1)}%',
      '末分钟量比${relativeVolume.toStringAsFixed(2)}',
    ];
    final surgeHit = surge >= _settings.surgePercent;
    final pullbackHit = pullback >= _settings.pullbackPercent;
    final volumeHit = relativeVolume >= _settings.relativeVolume;
    if (!surgeHit && !pullbackHit && !volumeHit) return const [];

    final score =
        60 + (surgeHit ? 12 : 0) + (pullbackHit ? 15 : 0) + (volumeHit ? 8 : 0);
    return [
      TradeSignal(
        id: 'intraday-gap-${stock.code}-${date.year}${date.month}${date.day}',
        code: stock.code,
        name: stock.name,
        title: pullbackHit ? '开盘冲高回落' : '开盘急速拉升',
        reason: '开盘${_settings.windowEndMinute}分钟监控：${reasons.join('，')}。',
        advice: pullbackHit ? '按纪律先减仓，避免高开低走扩大回撤。' : '冲高可先落袋一部分，剩余仓位观察承接。',
        disciplineId: 'gap_up_intraday',
        disciplineName: '跳空高开纪律',
        action: SignalAction.reduce,
        side: SignalSide.sell,
        triggeredAt: DateTime.now(),
        score: score.clamp(0, 100),
        dataSource: result.meta.sourceLabel,
        dataAt: result.meta.dataAt,
        timeframe: '1分钟',
        isIntraday: true,
        matchedConditions: reasons,
      ),
    ];
  }

  bool _isWithinWindow(DateTime now) {
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }
    final current = now.hour * 60 + now.minute;
    final start = 9 * 60 + 30 + _settings.windowStartMinute;
    final end = 9 * 60 + 30 + _settings.windowEndMinute;
    return current >= start && current <= end;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
