import '../models/candle.dart';
import '../models/rule.dart';
import '../models/signal.dart';
import '../services/stock_api_service.dart';

/// 跑路纪律：缩量破位 / 巨量 / 放量破位 / 动能衰竭。
class ExitDiscipline {
  static const id = 'exit';
  static const name = '跑路纪律';

  static const info = DisciplineInfo(
    id: id,
    name: name,
    summary: '缩量破位减半、巨量减半、放量破位清仓；连阳后长影线提示动能不足。',
    details: '''
1) 缩量破趋势线 → 出一半
  · 上升趋势（多数收盘在 5 日线上方且 5 日线向上）：跌破 5 日线且今日量能短于近几日 → 减半。
  · 箱体整理：跌破箱体下沿 → 减半。

2) 巨量 → 出一半
  · 今日量创观察窗口新高，且高于近 5 日均量约 20%～30% 以上 → 减半。

3) 放量破位 → 全部跑
  · 破位 + 巨量同时出现 → 清仓。

4) 动能衰竭（择优）
  · 连阳后出现长上影、长下影或纺锤/十字 → 警惕见顶，可择机减仓。
''',
  );

  List<TradeSignal> evaluate({
    required String code,
    required String name,
    required List<Candle> candles,
    RuleDefinition? rule,
  }) {
    if (candles.length < 10) return const [];
    final signals = <TradeSignal>[];
    final last = candles.last;
    final maDays = (rule?.value('maDays') ?? 5).round();
    final boxDays = (rule?.value('boxDays') ?? 20).round();
    final shrinkRatio = rule?.value('shrinkRatio') ?? 0.85;
    final hugeVolumeRatio = rule?.value('hugeVolumeRatio') ?? 1.25;
    final shadowRatio = (rule?.value('shadowRatio') ?? 45) / 100;
    final ma5 = Technicals.lastSma(candles, maDays);
    if (ma5 == null) return const [];

    final upTrend = _isUpTrend(candles, maDays);
    final volShrink = _isVolumeShrinking(candles, shrinkRatio);
    final brokeMa5 = last.close < ma5;
    final box = Technicals.boxRange(candles, lookback: boxDays);
    final brokeBox = last.close < box.support * 1.002 && upTrend == false;
    final hugeVol = _isHugeVolume(candles, hugeVolumeRatio);

    final broken = (upTrend && brokeMa5) || brokeBox;

    if (broken && hugeVol) {
      signals.add(
        _sig(
          code: code,
          name: name,
          title: '放量破位',
          reason: upTrend && brokeMa5
              ? '股价跌破$maDays日线且今日放巨量，破位成立。'
              : '跌破近箱体下沿且放巨量，形态走坏。',
          advice: '建议全部清仓离场，不要犹豫。',
          action: SignalAction.sellAll,
          score: 95,
        ),
      );
    } else if (broken && volShrink) {
      signals.add(
        _sig(
          code: code,
          name: name,
          title: '缩量破位',
          reason: upTrend && brokeMa5
              ? '上升趋势中跌破$maDays日线，且今日量能短于近几日。'
              : '股价跌破箱体下沿支撑。',
          advice: '建议先出一半仓位，剩余观察能否收回。',
          action: SignalAction.sellHalf,
          score: 80,
        ),
      );
    } else if (hugeVol && !broken) {
      signals.add(
        _sig(
          code: code,
          name: name,
          title: '巨量警戒',
          reason:
              '今日成交量显著高于近5日均量（约${((_relVol(candles) - 1) * 100).toStringAsFixed(0)}%），接近或创近期新高。',
          advice: '建议出一半锁定利润，防冲高回落。',
          action: SignalAction.sellHalf,
          score: 70,
        ),
      );
    }

    final momentum = _momentumExhaustion(candles, shadowRatio);
    if (momentum != null) {
      signals.add(momentum.copyWithCode(code, name));
    }

    return signals;
  }

  bool _isUpTrend(List<Candle> candles, int period) {
    if (candles.length < 8) return false;
    final ma = Technicals.sma(Technicals.closes(candles), period);
    var above = 0;
    final start = candles.length - 8;
    for (var i = start; i < candles.length; i++) {
      if (!ma[i].isNaN && candles[i].close >= ma[i]) above++;
    }
    return above >= 5 && Technicals.isMaTurningUp(candles, period);
  }

  bool _isVolumeShrinking(List<Candle> candles, double threshold) {
    final last = candles.last.volume;
    final prev = candles.sublist(candles.length - 4, candles.length - 1);
    final avg = prev.map((c) => c.volume).reduce((a, b) => a + b) / prev.length;
    return last < avg * threshold;
  }

  double _relVol(List<Candle> candles) {
    final avg5 = Technicals.avgVolume(
      candles.sublist(0, candles.length - 1),
      5,
    );
    if (avg5 <= 0) return 1;
    return candles.last.volume / avg5;
  }

  bool _isHugeVolume(List<Candle> candles, double threshold) {
    final window = candles.length < 30 ? candles.length : 30;
    final hist = candles.sublist(candles.length - window, candles.length - 1);
    if (hist.isEmpty) return false;
    final maxPrev = hist.map((c) => c.volume).reduce((a, b) => a > b ? a : b);
    final rel = _relVol(candles);
    return candles.last.volume >= maxPrev && rel >= threshold;
  }

  TradeSignal? _momentumExhaustion(
    List<Candle> candles,
    double shadowThreshold,
  ) {
    if (candles.length < 8) return null;
    final last = candles.last;
    final range = last.range;
    if (range <= 0) return null;

    var yangStreak = 0;
    for (var i = candles.length - 2; i >= 0 && yangStreak < 5; i--) {
      if (candles[i].isYang && candles[i].body > candles[i].range * 0.45) {
        yangStreak++;
      } else {
        break;
      }
    }
    if (yangStreak < 2) return null;

    final upperRatio = last.upperShadow / range;
    final lowerRatio = last.lowerShadow / range;
    final bodyRatio = last.body / range;

    String? pattern;
    if (upperRatio >= shadowThreshold && bodyRatio <= 0.4) {
      pattern = '长上影线';
    } else if (lowerRatio >= shadowThreshold && bodyRatio <= 0.4) {
      pattern = '长下影线';
    } else if (upperRatio >= 0.28 && lowerRatio >= 0.28 && bodyRatio <= 0.25) {
      pattern = '纺锤/十字星';
    }
    if (pattern == null) return null;

    final gain5 = _gainPct(candles, 5);
    return TradeSignal(
      id: '$id-momentum-${candles.last.date.toIso8601String()}',
      code: '',
      name: '',
      title: '形态走坏（预警减仓）',
      reason:
          '近${yangStreak + 1}日偏强上涨后出现$pattern；近5日累计涨幅约${gain5.toStringAsFixed(1)}%，上攻动能减弱，技术面见顶信号。',
      advice: '减仓1/3至1/2观察，防跳水。',
      disciplineId: id,
      disciplineName: ExitDiscipline.name,
      action: SignalAction.reduce,
      side: SignalSide.sell,
      triggeredAt: DateTime.now(),
      score: 65,
    );
  }

  double _gainPct(List<Candle> candles, int days) {
    if (candles.length <= days) return 0;
    final a = candles[candles.length - 1 - days].close;
    final b = candles.last.close;
    if (a == 0) return 0;
    return (b - a) / a * 100;
  }

  TradeSignal _sig({
    required String code,
    required String name,
    required String title,
    required String reason,
    required String advice,
    required SignalAction action,
    required int score,
  }) {
    return TradeSignal(
      id: '$id-$title-$code',
      code: code,
      name: name,
      title: title,
      reason: reason,
      advice: advice,
      disciplineId: id,
      disciplineName: ExitDiscipline.name,
      action: action,
      side: SignalSide.sell,
      triggeredAt: DateTime.now(),
      score: score,
    );
  }
}

extension on TradeSignal {
  TradeSignal copyWithCode(String code, String name) => TradeSignal(
    id: id.contains(code) ? id : '$id-$code',
    code: code,
    name: name,
    title: title,
    reason: reason,
    advice: advice,
    disciplineId: disciplineId,
    disciplineName: disciplineName,
    action: action,
    side: side,
    triggeredAt: triggeredAt,
    score: score,
  );
}
