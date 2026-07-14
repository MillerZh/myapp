import '../models/candle.dart';
import '../models/rule.dart';
import '../models/signal.dart';

/// 银行+证券急速拉升 → 科技易掉头。
class SectorCorrelationDiscipline {
  static const id = 'sector_corr';
  static const name = '板块联动因子';

  static const info = DisciplineInfo(
    id: id,
    name: name,
    summary: '银行与证券若急速拉升，科技板块往往容易掉头向下。',
    details: '''
重要量化因子：当银行、证券板块短线急速拉升时，科技方向容易出现获利回吐/资金切换，需降低科技仓位或暂缓追高。
完整宏中微观版本可后续继续扩充。
''',
  );

  static const bankSectors = {'银行'};
  static const brokerSectors = {'证券', '券商'};
  static const techSectors = {'科技', 'CPO', '光纤', 'PCB', '半导体', '软件', '人工智能'};

  List<TradeSignal> evaluateMarket({
    required Map<String, List<Candle>> sectorCandles,
    RuleDefinition? rule,
  }) {
    final days = (rule?.value('days') ?? 3).round();
    final threshold = (rule?.value('surgePercent') ?? 4) / 100;
    final bankGain = _maxGain(sectorCandles, bankSectors, days);
    final brokerGain = _maxGain(sectorCandles, brokerSectors, days);
    if (bankGain == null || brokerGain == null) return const [];

    // 「急速拉升」：近3日涨幅都偏强
    if (bankGain < threshold || brokerGain < threshold) return const [];

    return [
      TradeSignal(
        id: '$id-tech-warn',
        code: 'SECTOR',
        name: '科技板块',
        title: '银证急拉 · 科技承压',
        reason:
            '银行近3日约涨${(bankGain * 100).toStringAsFixed(1)}%，证券约涨${(brokerGain * 100).toStringAsFixed(1)}%，资金切向金融的概率上升。',
        advice: '科技方向慎追高，已有仓位可考虑减仓或收紧止盈；优先观察是否掉头。',
        disciplineId: id,
        disciplineName: name,
        action: SignalAction.sectorWarn,
        side: SignalSide.neutral,
        triggeredAt: DateTime.now(),
        score: 68,
      ),
    ];
  }

  List<TradeSignal> evaluateStock({
    required String code,
    required String name,
    required String? sector,
    required List<Candle> candles,
    required bool marketWarn,
    RuleDefinition? rule,
  }) {
    if (!marketWarn || sector == null) return const [];
    if (!techSectors.contains(sector)) return const [];
    if (candles.length < 5) return const [];

    return [
      TradeSignal(
        id: '$id-stock-$code',
        code: code,
        name: name,
        title: '板块切换风险',
        reason: '当前市场触发「银证急拉→科技承压」因子，该股归属$sector。',
        advice: '避免加仓科技；持仓可减仓或抬高卖出优先级。',
        disciplineId: id,
        disciplineName: SectorCorrelationDiscipline.name,
        action: SignalAction.reduce,
        side: SignalSide.sell,
        triggeredAt: DateTime.now(),
        score: 62,
      ),
    ];
  }

  double? _maxGain(Map<String, List<Candle>> map, Set<String> keys, int days) {
    double? best;
    for (final e in map.entries) {
      if (!keys.contains(e.key)) continue;
      final g = _gain(e.value, days);
      if (g == null) continue;
      best = best == null ? g : (g > best ? g : best);
    }
    return best;
  }

  double? _gain(List<Candle> candles, int days) {
    if (candles.length <= days) return null;
    final a = candles[candles.length - 1 - days].close;
    final b = candles.last.close;
    if (a == 0) return null;
    return (b - a) / a;
  }
}
