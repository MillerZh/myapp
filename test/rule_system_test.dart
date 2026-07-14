import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock/data/demo_data.dart';
import 'package:stock/disciplines/discipline_engine.dart';
import 'package:stock/disciplines/default_rules.dart';
import 'package:stock/models/rule.dart';
import 'package:stock/models/stock.dart';

void main() {
  test('规则序列化保留参数、版本和条件', () {
    final rule = RuleDefinition(
      id: 'custom_test',
      kind: RuleKind.custom,
      name: '高量比观察',
      summary: '量比放大',
      description: '观察承接',
      enabled: true,
      version: 3,
      parameters: const [],
      values: const {},
      conditions: const [
        RuleCondition(
          metric: RuleMetric.relativeVolume,
          operator: RuleOperator.greaterOrEqual,
          value: 1.5,
        ),
      ],
      history: [
        RuleVersion(
          version: 2,
          savedAt: DateTime(2026, 7, 1),
          values: const {},
          summary: '旧版',
        ),
      ],
      isBuiltIn: false,
    );

    final restored = RuleDefinition.fromJson(
      jsonDecode(jsonEncode(rule.toJson())) as Map<String, dynamic>,
    );

    expect(restored.version, 3);
    expect(restored.conditions.single.value, 1.5);
    expect(restored.history.single.version, 2);
    expect(restored.validate(), isEmpty);
  });

  test('超出参数范围的规则会被拒绝', () {
    final rule = DefaultRules.create().first;
    final invalid = rule.copyWith(values: {...rule.values, 'maDays': 100});
    expect(invalid.validate(), isNotEmpty);
  });

  test('自定义规则能由注册式引擎执行', () {
    final candles = DemoData.candlesFor('600519');
    const stock = WatchStock(code: '600519', name: '贵州茅台');
    final custom = RuleDefinition(
      id: 'always_drop',
      kind: RuleKind.custom,
      name: '回撤观察',
      summary: '阶段回撤大于负数，用于验证',
      description: '测试建议',
      enabled: true,
      version: 1,
      parameters: const [],
      values: const {},
      conditions: const [
        RuleCondition(
          metric: RuleMetric.dropFromPeakPercent,
          operator: RuleOperator.greaterOrEqual,
          value: -1,
        ),
      ],
      isBuiltIn: false,
    );

    final signals = DisciplineEngine().scan(
      targets: [(stock: stock, candles: candles)],
      rules: [custom],
      dataSource: '测试源',
    );

    expect(signals, hasLength(1));
    expect(signals.single.disciplineName, '回撤观察');
    expect(signals.single.ruleVersion, 1);
    expect(signals.single.dataSource, '测试源');
  });
}
