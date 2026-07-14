import 'candle.dart';

enum MarketTimeframe {
  minute1(1, '1分钟'),
  minute5(5, '5分钟'),
  minute15(15, '15分钟'),
  daily(101, '日线');

  const MarketTimeframe(this.eastMoneyCode, this.label);

  final int eastMoneyCode;
  final String label;
}

enum MarketDataSourceKind { eastmoney, mock, cache }

enum StockDataSource { eastmoney, mock }

class MarketDataMeta {
  const MarketDataMeta({
    required this.source,
    required this.fetchedAt,
    required this.dataAt,
    this.isStale = false,
    this.fromCache = false,
  });

  final MarketDataSourceKind source;
  final DateTime fetchedAt;
  final DateTime dataAt;
  final bool isStale;
  final bool fromCache;

  String get sourceLabel => switch (source) {
    MarketDataSourceKind.eastmoney => '东方财富',
    MarketDataSourceKind.mock => '演示数据',
    MarketDataSourceKind.cache => '真实缓存',
  };
}

class MarketDataResult<T> {
  const MarketDataResult({required this.data, required this.meta});

  final T data;
  final MarketDataMeta meta;
}

class IntradaySnapshot {
  const IntradaySnapshot({
    required this.code,
    required this.name,
    required this.preClose,
    required this.bars,
  });

  final String code;
  final String name;
  final double preClose;
  final List<Candle> bars;

  Candle? get latest => bars.isEmpty ? null : bars.last;
}

class MarketDataException implements Exception {
  const MarketDataException(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;

  @override
  String toString() => message;
}
