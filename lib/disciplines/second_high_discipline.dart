import '../models/candle.dart';
import '../models/rule.dart';
import '../models/signal.dart';
import '../services/stock_api_service.dart';

/// 深度回撤后的「二高点」与修复节奏。
class SecondHighDiscipline {
  static const id = 'second_high';
  static const name = '二高点与回撤修复';

  static const info = DisciplineInfo(
    id: id,
    name: name,
    summary: '大跌后难立即V反，需时间形成低于前高的二高点；急跌套牢盘更重。',
    details: '''
· 距前高深度回撤后，不要期待立刻V形反转。
· 通常先构筑「二高点」（低于历史高峰的次高），再谈真正修复。
· 急跌（如光纤/PCB类）套牢盘重，消化期更长；缓跌相对更容易。
· 被套者可借二高点附近减仓；修复期务必轻仓。
''',
  );

  List<TradeSignal> evaluate({
    required String code,
    required String name,
    required List<Candle> candles,
    String? sector,
    RuleDefinition? rule,
  }) {
    if (candles.length < 30) return const [];
    final lookback = (rule?.value('lookbackDays') ?? 90).round();
    final deepDrop = (rule?.value('deepDropPercent') ?? 18) / 100;
    final secondHighThreshold = (rule?.value('secondHighPercent') ?? 98) / 100;
    final nearThreshold = (rule?.value('nearPercent') ?? 97) / 100;
    final drop = Technicals.dropFromPeak(candles, lookback: lookback);
    final days = Technicals.daysSincePeak(candles, lookback: lookback);
    if (drop < deepDrop || days < 8) return const [];

    // 阶段高点
    final start = candles.length > lookback ? candles.length - lookback : 0;
    var truePeak = candles[start].high;
    var peakIdx = start;
    for (var i = start; i < candles.length; i++) {
      if (candles[i].high >= truePeak) {
        truePeak = candles[i].high;
        peakIdx = i;
      }
    }

    // 峰值之后的反弹高点（二高候选）
    var reboundHigh = 0.0;
    var reboundIdx = peakIdx;
    for (var i = peakIdx + 1; i < candles.length; i++) {
      if (candles[i].high > reboundHigh) {
        reboundHigh = candles[i].high;
        reboundIdx = i;
      }
    }

    final nearSecondHigh =
        reboundHigh > 0 &&
        reboundHigh < truePeak * secondHighThreshold &&
        candles.last.high >= reboundHigh * nearThreshold &&
        candles.length - 1 - reboundIdx <= 5;

    final speed = drop / (days == 0 ? 1 : days);
    final fastDrop = speed > 0.012;
    final sectorHint = sector == null || sector.isEmpty ? '' : '（$sector）';

    return [
      TradeSignal(
        id: '$id-repair-$code',
        code: code,
        name: name,
        title: '深度回撤待二高点',
        reason:
            '距阶段高点已回撤约${(drop * 100).toStringAsFixed(1)}%，历时约$days个交易日$sectorHint。'
            '${fastDrop ? '下跌偏急，套牢盘更重，修复往往更慢。' : '下跌节奏相对缓和。'}'
            '不宜期待直接V反，应等待低于前高的二高点结构。',
        advice: nearSecondHigh
            ? '接近/触及二高点区域，被套资金可考虑减仓离场；未建仓者勿追，轻仓或观望。'
            : '修复期保持轻仓；若持仓成本偏高，可设二高点附近分批退出计划。',
        disciplineId: id,
        disciplineName: SecondHighDiscipline.name,
        action: nearSecondHigh ? SignalAction.reduce : SignalAction.watch,
        side: SignalSide.sell,
        triggeredAt: DateTime.now(),
        score: nearSecondHigh ? 72 : 50,
      ),
    ];
  }
}
