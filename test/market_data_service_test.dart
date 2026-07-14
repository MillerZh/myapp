import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/models/market_data.dart';
import 'package:stock/services/stock_api_service.dart';

void main() {
  test('解析东方财富一分钟分时并保留真实来源', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('trends2'));
      return http.Response(
        jsonEncode({
          'data': {
            'code': '600519',
            'name': '贵州茅台',
            'preClose': 1500.0,
            'trends': [
              '2026-07-14 09:30,1530,1532,1535,1528,1000,1532000,1531',
              '2026-07-14 09:31,1532,1540,1542,1531,1800,2772000,1536',
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = EastMoneyStockApi(client: client);

    final result = await api.fetchIntraday('600519');

    expect(result.data.preClose, 1500);
    expect(result.data.bars, hasLength(2));
    expect(result.data.bars.last.close, 1540);
    expect(result.meta.source, MarketDataSourceKind.eastmoney);
    expect(result.meta.isStale, isFalse);
  });

  test('真实模式失败时不会静默返回模拟行情', () async {
    final failing = EastMoneyStockApi(
      client: MockClient((_) async => http.Response('failed', 503)),
    );
    final router = StockApiRouter(
      StockApiConfig(source: StockDataSource.eastmoney),
      eastMoney: failing,
    );

    expect(
      () => router.fetchKlines('600519'),
      throwsA(isA<MarketDataException>()),
    );
  });

  test('演示数据只在显式mock模式使用', () async {
    final router = StockApiRouter(StockApiConfig(source: StockDataSource.mock));
    final result = await router.fetchKlines('600519');
    expect(result.meta.source, MarketDataSourceKind.mock);
    expect(result.data, isNotEmpty);
  });
}
