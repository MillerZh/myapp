import '../models/candle.dart';
import '../models/rule.dart';
import '../models/signal.dart';

/// 跳空高开 + 影线出货/诱多纪律。
class GapUpDiscipline {
  static const id = 'gap_up';
  static const name = '跳空高开纪律';

  static const info = DisciplineInfo(
    id: id,
    name: name,
    summary: '大幅跳空后冲高先减仓；跳空小阳/长影线提示买力不足或诱多。',
    details: '''
· 大幅跳空高开后，开盘 15～20 分钟内急速拉升 → 可先卖一部分落袋。
· 跳空却只收小阳或带长影、未走出大阳：说明买盘无法承接。
· 长上影：偏出货；长下影（尤其尾盘回拉）：更偏诱多，需警惕。
（盘中 15～20 分钟规则依赖分钟线/盘中 tick，当前版本以日 K 跳空形态为主；接入分时后可加强。）
''',
  );

  List<TradeSignal> evaluate({
    required String code,
    required String name,
    required List<Candle> candles,
    RuleDefinition? rule,
  }) {
    if (candles.length < 3) return const [];
    final prev = candles[candles.length - 2];
    final last = candles.last;
    if (prev.close <= 0) return const [];

    final gapThreshold = (rule?.value('gapPercent') ?? 2) / 100;
    final strongGapThreshold = (rule?.value('strongGapPercent') ?? 3) / 100;
    final smallBodyThreshold = (rule?.value('smallBodyRatio') ?? 35) / 100;
    final shadowThreshold = (rule?.value('shadowRatio') ?? 40) / 100;
    final gapPct = (last.open - prev.close) / prev.close;
    if (gapPct < gapThreshold) return const [];

    final range = last.range;
    if (range <= 0) return const [];
    final bodyRatio = last.body / range;
    final upperRatio = last.upperShadow / range;
    final lowerRatio = last.lowerShadow / range;
    final isSmallBody = bodyRatio <= smallBodyThreshold;
    final isBigYang =
        last.isYang && bodyRatio >= 0.55 && last.close > last.open * 1.02;

    final signals = <TradeSignal>[];

    if (gapPct >= strongGapThreshold) {
      signals.add(
        TradeSignal(
          id: '$id-intraday-$code',
          code: code,
          name: name,
          title: '跳空高开冲高',
          reason:
              '今日相对昨收跳空约${(gapPct * 100).toStringAsFixed(1)}%。若开盘15～20分钟内急速冲高，属于典型兑现窗口。',
          advice: '冲高先减仓一部分；勿在情绪最高点加仓。',
          disciplineId: id,
          disciplineName: GapUpDiscipline.name,
          action: SignalAction.reduce,
          side: SignalSide.sell,
          triggeredAt: DateTime.now(),
          score: 60,
        ),
      );
    }

    if (!isBigYang &&
        (isSmallBody ||
            upperRatio >= shadowThreshold ||
            lowerRatio >= shadowThreshold)) {
      final kind = lowerRatio >= shadowThreshold && lowerRatio > upperRatio
          ? '长下影（偏诱多）'
          : upperRatio >= shadowThreshold
          ? '长上影（偏出货）'
          : '跳空小实体';
      signals.add(
        TradeSignal(
          id: '$id-pattern-$code',
          code: code,
          name: name,
          title: '跳空弱势K线',
          reason:
              '跳空高开约${(gapPct * 100).toStringAsFixed(1)}%后未能收大阳，出现$kind，买力不足。',
          advice: kind.contains('诱多') ? '高度警惕诱多，优先减仓或观望，勿追涨。' : '减仓锁定利润，防冲高回落。',
          disciplineId: id,
          disciplineName: GapUpDiscipline.name,
          action: SignalAction.reduce,
          side: SignalSide.sell,
          triggeredAt: DateTime.now(),
          score: 75,
        ),
      );
    }

    return signals;
  }
}
