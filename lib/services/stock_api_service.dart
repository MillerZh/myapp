import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../data/demo_data.dart';
import '../models/candle.dart';
import '../models/market_data.dart';
import '../models/stock.dart';

export '../models/market_data.dart'
    show
        MarketDataResult,
        MarketDataSourceKind,
        MarketTimeframe,
        StockDataSource;

class StockApiConfig {
  StockApiConfig({
    this.source = StockDataSource.eastmoney,
    this.customBaseUrl,
    this.apiToken,
  });

  StockDataSource source;

  /// 自定义行情 Base URL（预留）。约定路径见 CLAUDE.md。
  String? customBaseUrl;

  /// 可选 Token（预留）。
  String? apiToken;
}

abstract class StockApiService {
  Future<MarketDataResult<StockQuote>> fetchQuoteData(
    String code, {
    String? name,
    String? sector,
  });

  Future<MarketDataResult<List<Candle>>> fetchKlines(
    String code, {
    MarketTimeframe timeframe = MarketTimeframe.daily,
    int limit = 120,
  });

  Future<MarketDataResult<IntradaySnapshot>> fetchIntraday(
    String code, {
    int days = 1,
  });

  Future<List<StockQuote>> search(String keyword);

  Future<StockQuote> fetchQuote(
    String code, {
    String? name,
    String? sector,
  }) async {
    return (await fetchQuoteData(code, name: name, sector: sector)).data;
  }

  Future<List<Candle>> fetchDailyKlines(String code, {int limit = 120}) async {
    return (await fetchKlines(
      code,
      timeframe: MarketTimeframe.daily,
      limit: limit,
    )).data;
  }
}

class StockApiRouter extends StockApiService {
  StockApiRouter(
    this.config, {
    EastMoneyStockApi? eastMoney,
    MockStockApi? mock,
  }) : _east = eastMoney ?? EastMoneyStockApi(),
       _mock = mock ?? MockStockApi();

  final StockApiConfig config;
  final EastMoneyStockApi _east;
  final MockStockApi _mock;
  final Map<String, _CacheEntry<dynamic>> _cache = {};

  StockApiService get _active =>
      config.source == StockDataSource.mock ? _mock : _east;

  @override
  Future<MarketDataResult<StockQuote>> fetchQuoteData(
    String code, {
    String? name,
    String? sector,
  }) async {
    final key = 'quote:$code';
    try {
      final result = await _active.fetchQuoteData(
        code,
        name: name,
        sector: sector,
      );
      _cache[key] = _CacheEntry(result, DateTime.now());
      return result;
    } catch (error) {
      final cached = _cache[key];
      if (config.source == StockDataSource.eastmoney &&
          cached?.value is MarketDataResult<StockQuote>) {
        final result = cached!.value as MarketDataResult<StockQuote>;
        return MarketDataResult(
          data: result.data,
          meta: MarketDataMeta(
            source: MarketDataSourceKind.cache,
            fetchedAt: DateTime.now(),
            dataAt: result.meta.dataAt,
            isStale: true,
            fromCache: true,
          ),
        );
      }
      throw MarketDataException('获取 $code 实时报价失败：$error');
    }
  }

  @override
  Future<MarketDataResult<List<Candle>>> fetchKlines(
    String code, {
    MarketTimeframe timeframe = MarketTimeframe.daily,
    int limit = 120,
  }) async {
    final key = 'kline:$code:${timeframe.name}:$limit';
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.savedAt) <
            (timeframe == MarketTimeframe.daily
                ? const Duration(minutes: 30)
                : const Duration(seconds: 45))) {
      return cached.value as MarketDataResult<List<Candle>>;
    }
    try {
      final result = await _active.fetchKlines(
        code,
        timeframe: timeframe,
        limit: limit,
      );
      _cache[key] = _CacheEntry(result, DateTime.now());
      return result;
    } catch (error) {
      if (config.source == StockDataSource.eastmoney &&
          cached?.value is MarketDataResult<List<Candle>>) {
        final result = cached!.value as MarketDataResult<List<Candle>>;
        return MarketDataResult(
          data: result.data,
          meta: MarketDataMeta(
            source: MarketDataSourceKind.cache,
            fetchedAt: DateTime.now(),
            dataAt: result.meta.dataAt,
            isStale: true,
            fromCache: true,
          ),
        );
      }
      throw MarketDataException('获取 $code ${timeframe.label}失败：$error');
    }
  }

  @override
  Future<MarketDataResult<IntradaySnapshot>> fetchIntraday(
    String code, {
    int days = 1,
  }) async {
    final key = 'intraday:$code:$days';
    final cached = _cache[key];
    try {
      final result = await _active.fetchIntraday(code, days: days);
      _cache[key] = _CacheEntry(result, DateTime.now());
      return result;
    } catch (error) {
      if (config.source == StockDataSource.eastmoney &&
          cached?.value is MarketDataResult<IntradaySnapshot>) {
        final result = cached!.value as MarketDataResult<IntradaySnapshot>;
        return MarketDataResult(
          data: result.data,
          meta: MarketDataMeta(
            source: MarketDataSourceKind.cache,
            fetchedAt: DateTime.now(),
            dataAt: result.meta.dataAt,
            isStale: true,
            fromCache: true,
          ),
        );
      }
      throw MarketDataException('获取 $code 分时行情失败：$error');
    }
  }

  @override
  Future<List<StockQuote>> search(String keyword) => _active.search(keyword);

  void clearCache() => _cache.clear();
}

class MockStockApi extends StockApiService {
  @override
  Future<MarketDataResult<StockQuote>> fetchQuoteData(
    String code, {
    String? name,
    String? sector,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final quote = DemoData.quoteFor(code, name: name, sector: sector);
    final now = DateTime.now();
    return MarketDataResult(
      data: quote,
      meta: MarketDataMeta(
        source: MarketDataSourceKind.mock,
        fetchedAt: now,
        dataAt: now,
      ),
    );
  }

  @override
  Future<MarketDataResult<List<Candle>>> fetchKlines(
    String code, {
    MarketTimeframe timeframe = MarketTimeframe.daily,
    int limit = 120,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final candles = DemoData.candlesFor(code, count: limit);
    final now = DateTime.now();
    final adjusted = timeframe == MarketTimeframe.daily
        ? candles
        : _toMinuteDemo(candles.last, timeframe, limit);
    return MarketDataResult(
      data: adjusted,
      meta: MarketDataMeta(
        source: MarketDataSourceKind.mock,
        fetchedAt: now,
        dataAt: adjusted.isEmpty ? now : adjusted.last.date,
      ),
    );
  }

  @override
  Future<MarketDataResult<IntradaySnapshot>> fetchIntraday(
    String code, {
    int days = 1,
  }) async {
    final daily = DemoData.candlesFor(code, count: 2);
    final bars = _toMinuteDemo(
      daily.last,
      MarketTimeframe.minute1,
      math.max(20, days * 240),
    );
    final now = DateTime.now();
    return MarketDataResult(
      data: IntradaySnapshot(
        code: code,
        name: DemoData.quoteFor(code).name,
        preClose: daily.length > 1
            ? daily[daily.length - 2].close
            : daily.last.open,
        bars: bars,
      ),
      meta: MarketDataMeta(
        source: MarketDataSourceKind.mock,
        fetchedAt: now,
        dataAt: bars.isEmpty ? now : bars.last.date,
      ),
    );
  }

  @override
  Future<List<StockQuote>> search(String keyword) async {
    final q = keyword.trim().toLowerCase();
    return DemoData.seedWatchlist
        .where((s) => s.code.contains(q) || s.name.toLowerCase().contains(q))
        .map((s) => DemoData.quoteFor(s.code, name: s.name, sector: s.sector))
        .toList();
  }

  List<Candle> _toMinuteDemo(
    Candle daily,
    MarketTimeframe timeframe,
    int limit,
  ) {
    final step = timeframe == MarketTimeframe.minute1
        ? 1
        : timeframe == MarketTimeframe.minute5
        ? 5
        : 15;
    final count = math.min(limit, 240 ~/ step);
    final date = DateTime.now();
    var price = daily.open;
    final out = <Candle>[];
    for (var i = 0; i < count; i++) {
      final minute = i * step;
      final clockMinute = 30 + minute;
      final hour = 9 + clockMinute ~/ 60;
      final min = clockMinute % 60;
      final phase = math.sin(i / 4) * 0.004 + (i / count) * 0.012;
      final open = price;
      final close = daily.open * (1 + phase);
      out.add(
        Candle(
          date: DateTime(date.year, date.month, date.day, hour, min),
          open: open,
          high: math.max(open, close) * 1.002,
          low: math.min(open, close) * 0.998,
          close: close,
          volume: daily.volume / math.max(1, count),
          amount: close * daily.volume / math.max(1, count),
          pctChange: open == 0 ? 0 : (close - open) / open * 100,
        ),
      );
      price = close;
    }
    return out;
  }
}

/// 东方财富公开接口（无需 Token）。
/// Web 若遇 CORS，请在设置中切换为「演示数据」，或后续自行提供代理/私有 API。
class EastMoneyStockApi extends StockApiService {
  EastMoneyStockApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static String secIdOf(String code) {
    final c = code.replaceAll(RegExp(r'[^0-9]'), '').padLeft(6, '0');
    if (c.startsWith('6') || c.startsWith('9')) return '1.$c';
    return '0.$c';
  }

  @override
  Future<MarketDataResult<StockQuote>> fetchQuoteData(
    String code, {
    String? name,
    String? sector,
  }) async {
    final secid = secIdOf(code);
    final uri = Uri.parse(
      'https://push2.eastmoney.com/api/qt/stock/get'
      '?secid=$secid'
      '&fields=f57,f58,f43,f169,f170,f46,f44,f45,f60,f47,f48,f127',
    );
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('quote http ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('quote empty');

    double scale(num? v, [double div = 100]) =>
        v == null ? 0 : v.toDouble() / div;

    final price = scale(data['f43'] as num?);
    final changeAmt = scale(data['f169'] as num?);
    final changePct = scale(data['f170'] as num?);
    final quote = StockQuote(
      code: (data['f57'] as String?) ?? code,
      name: name ?? (data['f58'] as String?) ?? code,
      price: price,
      changePct: changePct,
      changeAmount: changeAmt,
      open: scale(data['f46'] as num?),
      high: scale(data['f44'] as num?),
      low: scale(data['f45'] as num?),
      preClose: scale(data['f60'] as num?),
      volume: (data['f47'] as num?)?.toDouble() ?? 0,
      amount: (data['f48'] as num?)?.toDouble() ?? 0,
      sector: sector ?? data['f127'] as String?,
    );
    final now = DateTime.now();
    return MarketDataResult(
      data: quote,
      meta: MarketDataMeta(
        source: MarketDataSourceKind.eastmoney,
        fetchedAt: now,
        dataAt: now,
      ),
    );
  }

  @override
  Future<MarketDataResult<List<Candle>>> fetchKlines(
    String code, {
    MarketTimeframe timeframe = MarketTimeframe.daily,
    int limit = 120,
  }) async {
    final secid = secIdOf(code);
    final uri = Uri.parse(
      'https://push2his.eastmoney.com/api/qt/stock/kline/get'
      '?fields1=f1,f2,f3,f4,f5,f6'
      '&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61'
      '&ut=7eea3edcaed734bea9cbfc24409ed989'
      '&klt=${timeframe.eastMoneyCode}&fqt=1'
      '&secid=$secid'
      '&beg=0&end=20500101'
      '&lmt=$limit',
    );
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('kline http ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    final raw = (data?['klines'] as List?)?.cast<String>() ?? const [];
    final candles = <Candle>[];
    for (final line in raw) {
      final p = line.split(',');
      if (p.length < 6) continue;
      candles.add(
        Candle(
          date: DateTime.parse(p[0]),
          open: double.parse(p[1]),
          close: double.parse(p[2]),
          high: double.parse(p[3]),
          low: double.parse(p[4]),
          volume: double.parse(p[5]),
          amount: p.length > 6 ? double.tryParse(p[6]) ?? 0 : 0,
          pctChange: p.length > 8 ? double.tryParse(p[8]) ?? 0 : 0,
        ),
      );
    }
    final result = candles.length > limit
        ? candles.sublist(candles.length - limit)
        : candles;
    if (result.isEmpty) throw const MarketDataException('K线数据为空');
    return MarketDataResult(
      data: result,
      meta: MarketDataMeta(
        source: MarketDataSourceKind.eastmoney,
        fetchedAt: DateTime.now(),
        dataAt: result.last.date,
      ),
    );
  }

  @override
  Future<MarketDataResult<IntradaySnapshot>> fetchIntraday(
    String code, {
    int days = 1,
  }) async {
    final secid = secIdOf(code);
    final uri = Uri.parse(
      'https://push2.eastmoney.com/api/qt/stock/trends2/get'
      '?fields1=f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,f13'
      '&fields2=f51,f52,f53,f54,f55,f56,f57,f58'
      '&ut=fb5fd1943c7b386f172d6893dbfba10b'
      '&ndays=${days.clamp(1, 5)}&iscr=1&secid=$secid',
    );
    final res = await _getWithRetry(uri);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) throw const MarketDataException('分时数据为空');
    final raw = (data['trends'] as List?)?.cast<String>() ?? const [];
    final bars = <Candle>[];
    for (final line in raw) {
      final p = line.split(',');
      if (p.length < 7) continue;
      final date = DateTime.tryParse(p[0]);
      if (date == null) continue;
      bars.add(
        Candle(
          date: date,
          open: double.tryParse(p[1]) ?? 0,
          close: double.tryParse(p[2]) ?? 0,
          high: double.tryParse(p[3]) ?? 0,
          low: double.tryParse(p[4]) ?? 0,
          volume: double.tryParse(p[5]) ?? 0,
          amount: double.tryParse(p[6]) ?? 0,
        ),
      );
    }
    if (bars.isEmpty) throw const MarketDataException('分时数据为空');
    final snapshot = IntradaySnapshot(
      code: data['code'] as String? ?? code,
      name: data['name'] as String? ?? code,
      preClose: (data['preClose'] as num?)?.toDouble() ?? bars.first.open,
      bars: bars,
    );
    return MarketDataResult(
      data: snapshot,
      meta: MarketDataMeta(
        source: MarketDataSourceKind.eastmoney,
        fetchedAt: DateTime.now(),
        dataAt: bars.last.date,
      ),
    );
  }

  @override
  Future<List<StockQuote>> search(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return const [];

    // 纯数字代码：直接拉报价
    if (RegExp(r'^\d{6}$').hasMatch(q)) {
      try {
        return [(await fetchQuoteData(q)).data];
      } catch (_) {
        rethrow;
      }
    }

    final uri = Uri.parse(
      'https://searchapi.eastmoney.com/api/suggest/get'
      '?input=${Uri.encodeQueryComponent(q)}'
      '&type=14'
      '&count=8',
    );
    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw MarketDataException('搜索接口 HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final qu = json['QuotationCodeTable'] as Map<String, dynamic>?;
      final list = (qu?['Data'] as List?) ?? const [];
      final out = <StockQuote>[];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final code = (m['Code'] as String?) ?? '';
        final name = (m['Name'] as String?) ?? code;
        final classify = (m['Classify'] as String?) ?? '';
        if (code.length != 6) continue;
        if (!classify.contains('A股') && !classify.contains('股票')) continue;
        out.add(
          StockQuote(
            code: code,
            name: name,
            price: 0,
            changePct: 0,
            changeAmount: 0,
          ),
        );
        if (out.length >= 8) break;
      }
      if (out.isEmpty) return const [];
      return out;
    } catch (error) {
      throw MarketDataException('搜索失败：$error');
    }
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) return response;
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    throw MarketDataException('请求失败：$lastError');
  }

  Map<String, String> get _headers => {
    'Referer': 'https://quote.eastmoney.com/',
    'User-Agent': 'Mozilla/5.0 (compatible; StockDisciplineApp/1.0)',
  };
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.savedAt);

  final T value;
  final DateTime savedAt;
}

class Technicals {
  static List<double> sma(List<double> values, int period) {
    final out = List<double>.filled(values.length, double.nan);
    if (values.length < period) return out;
    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      sum += values[i];
      if (i >= period) sum -= values[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  static List<double> closes(List<Candle> candles) =>
      candles.map((c) => c.close).toList();

  static double? lastSma(List<Candle> candles, int period) {
    final s = sma(closes(candles), period);
    if (s.isEmpty || s.last.isNaN) return null;
    return s.last;
  }

  static bool isMaTurningUp(List<Candle> candles, int period) {
    final s = sma(closes(candles), period);
    if (s.length < 3) return false;
    final a = s[s.length - 3];
    final b = s[s.length - 2];
    final c = s[s.length - 1];
    if (a.isNaN || b.isNaN || c.isNaN) return false;
    return c > b && b >= a;
  }

  static double avgVolume(List<Candle> candles, int lookback) {
    if (candles.isEmpty) return 0;
    final start = math.max(0, candles.length - lookback);
    final slice = candles.sublist(start);
    return slice.map((c) => c.volume).reduce((a, b) => a + b) / slice.length;
  }

  /// 近 [lookback] 根内最高收盘（不含最新一根，便于比「前高」）。
  static double priorPeakClose(List<Candle> candles, {int lookback = 60}) {
    if (candles.length < 2) return candles.isEmpty ? 0 : candles.last.close;
    final end = candles.length - 1;
    final start = math.max(0, end - lookback);
    var peak = candles[start].high;
    for (var i = start; i < end; i++) {
      peak = math.max(peak, candles[i].high);
    }
    return peak;
  }

  static int daysSincePeak(List<Candle> candles, {int lookback = 90}) {
    if (candles.isEmpty) return 0;
    final start = math.max(0, candles.length - lookback);
    var peakIdx = start;
    var peak = candles[start].high;
    for (var i = start; i < candles.length; i++) {
      if (candles[i].high >= peak) {
        peak = candles[i].high;
        peakIdx = i;
      }
    }
    return candles.length - 1 - peakIdx;
  }

  static double dropFromPeak(List<Candle> candles, {int lookback = 90}) {
    if (candles.isEmpty) return 0;
    final start = math.max(0, candles.length - lookback);
    var peak = candles[start].high;
    for (var i = start; i < candles.length; i++) {
      peak = math.max(peak, candles[i].high);
    }
    final last = candles.last.close;
    if (peak <= 0) return 0;
    return (peak - last) / peak;
  }

  /// 简易箱体：近 N 日高低中枢的下沿。
  static ({double support, double resist}) boxRange(
    List<Candle> candles, {
    int lookback = 20,
  }) {
    final start = math.max(0, candles.length - lookback);
    final slice = candles.sublist(start);
    final lo = slice.map((c) => c.low).reduce(math.min);
    final hi = slice.map((c) => c.high).reduce(math.max);
    return (support: lo, resist: hi);
  }
}
