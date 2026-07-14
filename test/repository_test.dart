import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock/models/signal.dart';
import 'package:stock/services/app_repositories.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('信号历史按股票、规则、标题和冷却时间去重', () async {
    final repository = SignalRepository();
    final now = DateTime(2026, 7, 14, 9, 50);
    final first = _signal(now);
    final duplicate = _signal(now.add(const Duration(minutes: 10)));
    final later = _signal(now.add(const Duration(minutes: 90)));

    var history = await repository.appendDeduplicated(const [], [
      first,
    ], cooldownMinutes: 60);
    history = await repository.appendDeduplicated(history, [
      duplicate,
      later,
    ], cooldownMinutes: 60);

    expect(history, hasLength(2));
    expect((await repository.load()), hasLength(2));
  });
}

TradeSignal _signal(DateTime time) => TradeSignal(
  id: 'signal-${time.millisecondsSinceEpoch}',
  code: '600519',
  name: '贵州茅台',
  title: '开盘冲高回落',
  reason: '测试',
  advice: '测试',
  disciplineId: 'gap_up',
  disciplineName: '跳空高开纪律',
  action: SignalAction.reduce,
  side: SignalSide.sell,
  triggeredAt: time,
  isIntraday: true,
);
