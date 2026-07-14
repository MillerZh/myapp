import 'package:flutter_test/flutter_test.dart';
import 'package:stock/data/demo_data.dart';
import 'package:stock/disciplines/discipline_engine.dart';
import 'package:stock/models/stock.dart';

void main() {
  test('纪律引擎能对演示K线产出信号', () {
    final engine = DisciplineEngine();
    final targets = DemoData.seedWatchlist
        .map((s) => (stock: s, candles: DemoData.candlesFor(s.code)))
        .toList();

    final sector = {
      '银行': DemoData.candlesFor('000001', count: 30),
      '证券': DemoData.candlesFor('600030', count: 30),
      '科技': DemoData.candlesFor('002230', count: 30),
    };

    final signals = engine.scan(targets: targets, sectorSeries: sector);
    expect(signals, isA<List>());
    // 演示数据场景设计为更容易命中至少一类规则
    expect(signals, isNotEmpty);
  });

  test('WatchStock 序列化往返', () {
    const s = WatchStock(code: '600519', name: '贵州茅台', sector: '白酒');
    final again = WatchStock.fromJson(s.toJson());
    expect(again.code, '600519');
    expect(again.name, '贵州茅台');
    expect(again.sector, '白酒');
  });
}
