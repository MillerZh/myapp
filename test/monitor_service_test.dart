import 'package:flutter_test/flutter_test.dart';
import 'package:stock/models/app_settings.dart';
import 'package:stock/models/candle.dart';
import 'package:stock/models/market_data.dart';
import 'package:stock/models/signal.dart';
import 'package:stock/models/stock.dart';
import 'package:stock/services/monitor_service.dart';
import 'package:stock/services/stock_api_service.dart';

void main() {
  test('开盘20分钟监控识别跳空冲高回落', () async {
    final service = IntradayMonitorService(api: _IntradayApi());
    List<TradeSignal> delivered = const [];
    service.configure(
      settings: const MonitorSettings(
        enabled: false,
        gapPercent: 3,
        surgePercent: 2,
        pullbackPercent: 1,
        relativeVolume: 1.2,
      ),
      targetsProvider: () => const [WatchStock(code: '600519', name: '贵州茅台')],
      onSignals: (signals) async => delivered = signals,
    );

    final result = await service.checkNow(force: true);

    expect(result, hasLength(1));
    expect(result.single.isIntraday, isTrue);
    expect(result.single.dataSource, '东方财富');
    expect(delivered, hasLength(1));
    service.dispose();
  });
}

class _IntradayApi extends MockStockApi {
  @override
  Future<MarketDataResult<IntradaySnapshot>> fetchIntraday(
    String code, {
    int days = 1,
  }) async {
    final date = DateTime(2026, 7, 14);
    final bars = [
      Candle(
        date: DateTime(date.year, date.month, date.day, 9, 30),
        open: 103,
        high: 103.5,
        low: 102.8,
        close: 103.2,
        volume: 100,
      ),
      Candle(
        date: DateTime(date.year, date.month, date.day, 9, 40),
        open: 103.2,
        high: 106,
        low: 103,
        close: 105.5,
        volume: 120,
      ),
      Candle(
        date: DateTime(date.year, date.month, date.day, 9, 50),
        open: 105.5,
        high: 105.7,
        low: 103.8,
        close: 104,
        volume: 240,
      ),
    ];
    return MarketDataResult(
      data: IntradaySnapshot(
        code: code,
        name: '贵州茅台',
        preClose: 100,
        bars: bars,
      ),
      meta: MarketDataMeta(
        source: MarketDataSourceKind.eastmoney,
        fetchedAt: DateTime.now(),
        dataAt: bars.last.date,
      ),
    );
  }
}
