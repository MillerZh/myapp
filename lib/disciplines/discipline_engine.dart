import '../models/candle.dart';
import '../models/rule.dart';
import '../models/signal.dart';
import '../models/stock.dart';
import '../services/stock_api_service.dart';
import 'default_rules.dart';
import 'exit_discipline.dart';
import 'gap_up_discipline.dart';
import 'second_high_discipline.dart';
import 'sector_correlation.dart';

class DisciplineEngine {
  DisciplineEngine({
    ExitDiscipline? exit,
    GapUpDiscipline? gapUp,
    SecondHighDiscipline? secondHigh,
    SectorCorrelationDiscipline? sector,
  }) : _exit = exit ?? ExitDiscipline(),
       _gapUp = gapUp ?? GapUpDiscipline(),
       _secondHigh = secondHigh ?? SecondHighDiscipline(),
       _sector = sector ?? SectorCorrelationDiscipline();

  final ExitDiscipline _exit;
  final GapUpDiscipline _gapUp;
  final SecondHighDiscipline _secondHigh;
  final SectorCorrelationDiscipline _sector;

  static List<DisciplineInfo> get catalog => DefaultRules.create()
      .map(
        (rule) => DisciplineInfo(
          id: rule.id,
          name: rule.name,
          summary: rule.summary,
          details: rule.description,
        ),
      )
      .toList();

  /// [sectorSeries]：板块名 → 代表股日 K，用于银证科技联动。
  List<TradeSignal> scan({
    required List<({WatchStock stock, List<Candle> candles})> targets,
    Map<String, List<Candle>> sectorSeries = const {},
    List<RuleDefinition>? rules,
    String dataSource = '未知',
    DateTime? dataAt,
  }) {
    final activeRules = rules ?? DefaultRules.create();
    RuleDefinition? find(String id) {
      for (final rule in activeRules) {
        if (rule.id == id && rule.enabled) return rule;
      }
      return null;
    }

    final sectorRule = find(SectorCorrelationDiscipline.id);
    final marketSignals = sectorRule == null
        ? <TradeSignal>[]
        : _sector.evaluateMarket(sectorCandles: sectorSeries, rule: sectorRule);
    final marketWarn = marketSignals.isNotEmpty;
    final out = <TradeSignal>[
      ...marketSignals.map(
        (signal) => _enrich(
          signal,
          rule: sectorRule!,
          dataSource: dataSource,
          dataAt: dataAt,
        ),
      ),
    ];

    for (final t in targets) {
      final code = t.stock.code;
      final name = t.stock.name;
      final sector = t.stock.sector;
      final candles = t.candles;
      if (candles.length < 5) continue;

      final exitRule = find(ExitDiscipline.id);
      final gapRule = find(GapUpDiscipline.id);
      final secondRule = find(SecondHighDiscipline.id);
      if (exitRule != null) {
        out.addAll(
          _exit
              .evaluate(
                code: code,
                name: name,
                candles: candles,
                rule: exitRule,
              )
              .map(
                (signal) => _enrich(
                  signal,
                  rule: exitRule,
                  dataSource: dataSource,
                  dataAt: dataAt ?? candles.last.date,
                ),
              ),
        );
      }
      if (gapRule != null) {
        out.addAll(
          _gapUp
              .evaluate(code: code, name: name, candles: candles, rule: gapRule)
              .map(
                (signal) => _enrich(
                  signal,
                  rule: gapRule,
                  dataSource: dataSource,
                  dataAt: dataAt ?? candles.last.date,
                ),
              ),
        );
      }
      if (secondRule != null) {
        out.addAll(
          _secondHigh
              .evaluate(
                code: code,
                name: name,
                candles: candles,
                sector: sector,
                rule: secondRule,
              )
              .map(
                (signal) => _enrich(
                  signal,
                  rule: secondRule,
                  dataSource: dataSource,
                  dataAt: dataAt ?? candles.last.date,
                ),
              ),
        );
      }
      if (sectorRule != null) {
        out.addAll(
          _sector
              .evaluateStock(
                code: code,
                name: name,
                sector: sector,
                candles: candles,
                marketWarn: marketWarn,
                rule: sectorRule,
              )
              .map(
                (signal) => _enrich(
                  signal,
                  rule: sectorRule,
                  dataSource: dataSource,
                  dataAt: dataAt ?? candles.last.date,
                ),
              ),
        );
      }
      for (final custom in activeRules.where(
        (rule) => rule.enabled && rule.kind == RuleKind.custom,
      )) {
        final signal = _evaluateCustom(custom, t.stock, candles);
        if (signal != null) {
          out.add(
            _enrich(
              signal,
              rule: custom,
              dataSource: dataSource,
              dataAt: dataAt ?? candles.last.date,
            ),
          );
        }
      }
    }

    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  TradeSignal _enrich(
    TradeSignal signal, {
    required RuleDefinition rule,
    required String dataSource,
    DateTime? dataAt,
  }) {
    return signal.copyWith(
      disciplineName: rule.name,
      ruleVersion: rule.version,
      dataSource: dataSource,
      dataAt: dataAt,
    );
  }

  TradeSignal? _evaluateCustom(
    RuleDefinition rule,
    WatchStock stock,
    List<Candle> candles,
  ) {
    if (candles.length < 6) return null;
    final metrics = _metrics(candles);
    final matched = <String>[];
    for (final condition in rule.conditions) {
      final actual = metrics[condition.metric];
      if (actual == null || !condition.evaluate(actual)) return null;
      matched.add(
        '${_metricLabel(condition.metric)}=${actual.toStringAsFixed(2)}',
      );
    }
    return TradeSignal(
      id: '${rule.id}-${stock.code}-${candles.last.date.toIso8601String()}',
      code: stock.code,
      name: stock.name,
      title: rule.name,
      reason: '自定义条件全部满足：${matched.join('，')}。',
      advice: rule.description.isEmpty ? '请按自定义纪律执行并控制仓位。' : rule.description,
      disciplineId: rule.id,
      disciplineName: rule.name,
      action: SignalAction.watch,
      side: SignalSide.neutral,
      triggeredAt: DateTime.now(),
      score: 60,
      matchedConditions: matched,
    );
  }

  Map<RuleMetric, double> _metrics(List<Candle> candles) {
    final last = candles.last;
    final prev = candles[candles.length - 2];
    final range = last.range == 0 ? 1 : last.range;
    final ma5 = Technicals.lastSma(candles, 5) ?? last.close;
    final avgVol = Technicals.avgVolume(
      candles.sublist(0, candles.length - 1),
      5,
    );
    final first = candles[candles.length - 4].close;
    var streak = 0;
    for (var i = candles.length - 1; i >= 0 && candles[i].isYang; i--) {
      streak++;
    }
    return {
      RuleMetric.gapPercent: prev.close == 0
          ? 0
          : (last.open - prev.close) / prev.close * 100,
      RuleMetric.relativeVolume: avgVol == 0 ? 0 : last.volume / avgVol,
      RuleMetric.closeBelowMaPercent: ma5 == 0
          ? 0
          : (ma5 - last.close) / ma5 * 100,
      RuleMetric.dropFromPeakPercent:
          Technicals.dropFromPeak(candles, lookback: 90) * 100,
      RuleMetric.upperShadowRatio: last.upperShadow / range * 100,
      RuleMetric.lowerShadowRatio: last.lowerShadow / range * 100,
      RuleMetric.bodyRatio: last.body / range * 100,
      RuleMetric.consecutiveYangDays: streak.toDouble(),
      RuleMetric.threeDayGainPercent: first == 0
          ? 0
          : (last.close - first) / first * 100,
      RuleMetric.openGainPercent: prev.close == 0
          ? 0
          : (last.close - prev.close) / prev.close * 100,
      RuleMetric.pullbackPercent: last.high == 0
          ? 0
          : (last.high - last.close) / last.high * 100,
    };
  }

  String _metricLabel(RuleMetric metric) => switch (metric) {
    RuleMetric.gapPercent => '跳空幅度',
    RuleMetric.openGainPercent => '开盘涨幅',
    RuleMetric.pullbackPercent => '高点回落',
    RuleMetric.relativeVolume => '相对量能',
    RuleMetric.closeBelowMaPercent => '均线下方',
    RuleMetric.dropFromPeakPercent => '高点回撤',
    RuleMetric.upperShadowRatio => '上影比例',
    RuleMetric.lowerShadowRatio => '下影比例',
    RuleMetric.bodyRatio => '实体比例',
    RuleMetric.consecutiveYangDays => '连续阳线',
    RuleMetric.threeDayGainPercent => '三日涨幅',
  };
}
