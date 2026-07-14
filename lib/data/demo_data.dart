import '../models/candle.dart';
import '../models/stock.dart';

/// 演示股票池与可复现的合成日 K（API 失败 / Web CORS 时使用）。
class DemoData {
  static const List<WatchStock> seedWatchlist = [
    WatchStock(code: '600519', name: '贵州茅台', sector: '白酒'),
    WatchStock(code: '000001', name: '平安银行', sector: '银行'),
    WatchStock(code: '600030', name: '中信证券', sector: '证券'),
    WatchStock(code: '002230', name: '科大讯飞', sector: '科技'),
    WatchStock(code: '300502', name: '新易盛', sector: 'CPO'),
    WatchStock(code: '002463', name: '沪电股份', sector: 'PCB'),
    WatchStock(code: '002837', name: '英维克', sector: '科技'),
  ];

  static const List<Holding> seedHoldings = [
    Holding(
      code: '300502',
      name: '新易盛',
      shares: 200,
      costPrice: 128.5,
      sector: 'CPO',
    ),
    Holding(
      code: '002463',
      name: '沪电股份',
      shares: 500,
      costPrice: 42.8,
      sector: 'PCB',
    ),
    Holding(
      code: '002230',
      name: '科大讯飞',
      shares: 300,
      costPrice: 48.2,
      sector: '科技',
    ),
  ];

  static StockQuote quoteFor(String code, {String? name, String? sector}) {
    final candles = candlesFor(code);
    final last = candles.last;
    final prev = candles[candles.length - 2];
    final change = last.close - prev.close;
    final pct = prev.close == 0 ? 0.0 : change / prev.close * 100;
    return StockQuote(
      code: code,
      name: name ?? _nameOf(code),
      price: last.close,
      changePct: pct,
      changeAmount: change,
      open: last.open,
      high: last.high,
      low: last.low,
      preClose: prev.close,
      volume: last.volume,
      amount: last.amount,
      sector: sector ?? _sectorOf(code),
    );
  }

  static List<Candle> candlesFor(String code, {int count = 120}) {
    final seed = code.hashCode.abs();
    final scenario = seed % 5;
    final base = 20.0 + (seed % 80).toDouble();
    final now = DateTime.now();
    final list = <Candle>[];
    var price = base;
    var vol = 80000.0 + (seed % 50000);

    for (var i = count; i >= 1; i--) {
      final d = now.subtract(Duration(days: i));
      // 跳过周末
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        continue;
      }

      final t = count - i;
      double drift;
      double shock = ((seed + t * 17) % 100) / 1000 - 0.05;

      switch (scenario) {
        case 0: // 急跌后弱势反弹 — 二高点场景
          if (t < 40) {
            drift = 0.012;
          } else if (t < 70) {
            drift = -0.028;
          } else {
            drift = 0.008 + (t > 95 ? -0.01 : 0);
          }
          vol = t > 40 && t < 55 ? vol * 1.4 : vol * 0.98;
          break;
        case 1: // 上升趋势后缩量跌破 5 日
          drift = t < count - 5 ? 0.01 : -0.018;
          vol = t >= count - 3 ? vol * 0.55 : vol * 1.02;
          break;
        case 2: // 巨量冲高
          drift = t < count - 2 ? 0.012 : 0.035;
          vol = t >= count - 1 ? vol * 2.8 : vol * 1.01;
          break;
        case 3: // 跳空 + 长上影
          if (t == count - 1) {
            final open = price * 1.04;
            final high = open * 1.03;
            final close = open * 1.005;
            final low = open * 0.99;
            list.add(
              Candle(
                date: d,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: vol * 1.6,
                amount: close * vol * 1.6,
                pctChange: (close - price) / price * 100,
              ),
            );
            price = close;
            continue;
          }
          drift = 0.006;
          break;
        default: // 连阳后纺锤线
          if (t >= count - 6 && t < count - 1) {
            drift = 0.022;
            vol *= 1.15;
          } else if (t == count - 1) {
            final open = price;
            final high = price * 1.04;
            final low = price * 0.96;
            final close = price * 1.002;
            list.add(
              Candle(
                date: d,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: vol * 0.9,
                amount: close * vol * 0.9,
                pctChange: 0.2,
              ),
            );
            price = close;
            continue;
          } else {
            drift = 0.004;
          }
      }

      final open = price * (1 + shock * 0.3);
      final close = open * (1 + drift + shock);
      final high =
          (open > close ? open : close) * (1 + 0.008 + (shock.abs() * 0.4));
      final low =
          (open < close ? open : close) * (1 - 0.008 - (shock.abs() * 0.3));
      final dayVol = vol * (0.85 + ((seed + t) % 30) / 100);

      list.add(
        Candle(
          date: d,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: dayVol,
          amount: close * dayVol,
          pctChange: (close - price) / price * 100,
        ),
      );
      price = close;
      vol = dayVol;
    }

    return list.length > count ? list.sublist(list.length - count) : list;
  }

  static String _nameOf(String code) {
    for (final s in seedWatchlist) {
      if (s.code == code) return s.name;
    }
    for (final h in seedHoldings) {
      if (h.code == code) return h.name;
    }
    return code;
  }

  static String? _sectorOf(String code) {
    for (final s in seedWatchlist) {
      if (s.code == code) return s.sector;
    }
    for (final h in seedHoldings) {
      if (h.code == code) return h.sector;
    }
    return null;
  }
}
