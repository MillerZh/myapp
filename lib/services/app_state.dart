import 'package:flutter/foundation.dart';

import '../data/demo_data.dart';
import '../disciplines/discipline_engine.dart';
import '../disciplines/default_rules.dart';
import '../models/ai_analysis.dart';
import '../models/app_settings.dart';
import '../models/candle.dart';
import '../models/market_data.dart';
import '../models/rule.dart';
import '../models/signal.dart';
import '../models/stock.dart';
import 'app_repositories.dart';
import 'background_task_service.dart';
import 'llm_service.dart';
import 'monitor_service.dart';
import 'notification_service.dart';
import 'stock_api_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.apiConfig,
    StockApiService? api,
    DisciplineEngine? engine,
    PortfolioRepository? portfolioRepository,
    SettingsRepository? settingsRepository,
    RuleRepository? ruleRepository,
    SignalRepository? signalRepository,
    SecureTokenRepository? tokenRepository,
    LlmService? llmService,
  }) : api = api ?? StockApiRouter(apiConfig),
       engine = engine ?? DisciplineEngine(),
       _portfolioRepository = portfolioRepository ?? PortfolioRepository(),
       _settingsRepository = settingsRepository ?? SettingsRepository(),
       _ruleRepository = ruleRepository ?? RuleRepository(),
       _signalRepository = signalRepository ?? SignalRepository(),
       _tokenRepository = tokenRepository ?? SecureTokenRepository(),
       llmService = llmService ?? LlmService() {
    monitor = IntradayMonitorService(api: this.api);
    monitor.addListener(_onMonitorChanged);
  }

  final StockApiConfig apiConfig;
  final StockApiService api;
  final DisciplineEngine engine;
  final PortfolioRepository _portfolioRepository;
  final SettingsRepository _settingsRepository;
  final RuleRepository _ruleRepository;
  final SignalRepository _signalRepository;
  final SecureTokenRepository _tokenRepository;
  final LlmService llmService;
  late final IntradayMonitorService monitor;

  List<WatchStock> watchlist = List.of(DemoData.seedWatchlist);
  List<Holding> holdings = List.of(DemoData.seedHoldings);
  List<TradeSignal> signals = const [];
  List<TradeSignal> signalHistory = const [];
  List<RuleDefinition> rules = DefaultRules.create();
  AppSettings settings = const AppSettings();
  Map<String, StockQuote> quotes = {};
  Map<String, MarketDataMeta> quoteMetadata = {};
  bool loadingSignals = false;
  bool loadingQuotes = false;
  bool initialized = false;
  String? lastError;
  DateTime? lastScanAt;

  Future<void> load() async {
    settings = await _settingsRepository.load();
    apiConfig.source = settings.dataSource;
    final portfolio = await _portfolioRepository.load();
    watchlist = portfolio.watchlist;
    holdings = portfolio.holdings;
    rules = await _ruleRepository.load();
    signalHistory = await _signalRepository.load();
    _configureMonitor();
    await BackgroundTaskService.syncRegistration(
      enabled: settings.monitor.enabled,
    );
    initialized = true;
    notifyListeners();
    await refreshQuotes();
  }

  Future<void> setDataSource(StockDataSource source) async {
    apiConfig.source = source;
    settings = settings.copyWith(dataSource: source);
    await _settingsRepository.save(settings);
    if (api is StockApiRouter) (api as StockApiRouter).clearCache();
    notifyListeners();
    await refreshQuotes();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    apiConfig.source = next.dataSource;
    await _settingsRepository.save(next);
    _configureMonitor();
    await BackgroundTaskService.syncRegistration(enabled: next.monitor.enabled);
    notifyListeners();
  }

  Future<void> updateMonitorSettings(MonitorSettings monitorSettings) =>
      updateSettings(settings.copyWith(monitor: monitorSettings));

  Future<void> updateLlmConfig(LlmConfig config, {String? token}) async {
    settings = settings.copyWith(llm: config);
    await _settingsRepository.save(settings);
    if (token != null) await _tokenRepository.write(token);
    notifyListeners();
  }

  Future<String> readLlmToken() => _tokenRepository.read();

  Future<void> clearLlmToken() => _tokenRepository.clear();

  Future<void> testLlmConnection({
    required LlmConfig config,
    required String token,
  }) => llmService.testConnection(config, token);

  Future<void> _persistPortfolio() =>
      _portfolioRepository.save(watchlist, holdings);

  Future<void> saveRule(RuleDefinition edited) async {
    final errors = edited.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    final index = rules.indexWhere((item) => item.id == edited.id);
    if (index < 0) {
      rules = [...rules, edited];
    } else {
      final next = _ruleRepository.createNextVersion(rules[index], edited);
      rules = [...rules]..[index] = next;
    }
    await _ruleRepository.saveAll(rules);
    notifyListeners();
  }

  Future<void> toggleRule(String id, bool enabled) async {
    final index = rules.indexWhere((item) => item.id == id);
    if (index < 0) return;
    await saveRule(rules[index].copyWith(enabled: enabled));
  }

  Future<void> deleteRule(String id) async {
    final rule = rules.where((item) => item.id == id).firstOrNull;
    if (rule == null || rule.isBuiltIn) return;
    rules = rules.where((item) => item.id != id).toList();
    await _ruleRepository.saveAll(rules);
    notifyListeners();
  }

  Future<void> restoreDefaultRules() async {
    rules = DefaultRules.create();
    await _ruleRepository.saveAll(rules);
    notifyListeners();
  }

  String exportRules() => _ruleRepository.exportJson(rules);

  Future<void> importRules(String raw) async {
    rules = _ruleRepository.importJson(raw);
    await _ruleRepository.saveAll(rules);
    notifyListeners();
  }

  Future<void> addWatch(WatchStock stock) async {
    if (watchlist.any((e) => e.code == stock.code)) return;
    watchlist = [...watchlist, stock];
    await _persistPortfolio();
    _configureMonitor();
    notifyListeners();
    await refreshQuotes();
  }

  Future<void> removeWatch(String code) async {
    watchlist = watchlist.where((e) => e.code != code).toList();
    await _persistPortfolio();
    _configureMonitor();
    notifyListeners();
  }

  Future<void> addHolding(Holding holding) async {
    holdings = [...holdings.where((e) => e.code != holding.code), holding];
    await _persistPortfolio();
    _configureMonitor();
    notifyListeners();
    await refreshQuotes();
  }

  Future<void> removeHolding(String code) async {
    holdings = holdings.where((e) => e.code != code).toList();
    await _persistPortfolio();
    _configureMonitor();
    notifyListeners();
  }

  Future<void> resetDemoPortfolio() async {
    watchlist = List.of(DemoData.seedWatchlist);
    holdings = List.of(DemoData.seedHoldings);
    await _persistPortfolio();
    _configureMonitor();
    notifyListeners();
    await refreshQuotes();
  }

  Set<String> get allCodes {
    final set = <String>{};
    for (final w in watchlist) {
      set.add(w.code);
    }
    for (final h in holdings) {
      set.add(h.code);
    }
    return set;
  }

  WatchStock metaOf(String code) {
    for (final h in holdings) {
      if (h.code == code) {
        return WatchStock(code: h.code, name: h.name, sector: h.sector);
      }
    }
    for (final w in watchlist) {
      if (w.code == code) {
        return WatchStock(
          code: w.code,
          name: w.name,
          sector: w.sector ?? quotes[code]?.sector,
        );
      }
    }
    return WatchStock(code: code, name: code);
  }

  Future<void> refreshQuotes() async {
    loadingQuotes = true;
    lastError = null;
    final next = <String, StockQuote>{};
    final nextMeta = <String, MarketDataMeta>{};
    final errors = <String>[];
    final codes = allCodes.toList();
    for (var start = 0; start < codes.length; start += 6) {
      final batch = codes.sublist(
        start,
        start + 6 < codes.length ? start + 6 : codes.length,
      );
      await Future.wait(
        batch.map((code) async {
          final stock = metaOf(code);
          try {
            final result = await api.fetchQuoteData(
              code,
              name: stock.name,
              sector: stock.sector,
            );
            next[code] = result.data;
            nextMeta[code] = result.meta;
          } catch (error) {
            errors.add('$code：$error');
          }
        }),
      );
    }
    quotes = next;
    quoteMetadata = nextMeta;
    lastError = errors.isEmpty ? null : errors.join('\n');
    loadingQuotes = false;
    notifyListeners();
  }

  Future<void> scanSignals() async {
    if (loadingSignals) return;
    loadingSignals = true;
    lastError = null;
    notifyListeners();
    try {
      final codes = allCodes.toList();
      final targets = <({WatchStock stock, List<Candle> candles})>[];
      final metadata = <MarketDataMeta>[];
      for (var start = 0; start < codes.length; start += 4) {
        final batch = codes.sublist(
          start,
          start + 4 < codes.length ? start + 4 : codes.length,
        );
        final results = await Future.wait(
          batch.map((code) async {
            final meta = metaOf(code);
            final data = await api.fetchKlines(
              code,
              timeframe: MarketTimeframe.daily,
              limit: 120,
            );
            return (stock: meta, result: data);
          }),
        );
        for (final item in results) {
          targets.add((stock: item.stock, candles: item.result.data));
          metadata.add(item.result.meta);
        }
      }

      final sectorSeries = <String, List<Candle>>{};
      for (final e in SectorProxy.proxies.entries) {
        sectorSeries[e.key] = (await api.fetchKlines(
          e.value,
          timeframe: MarketTimeframe.daily,
          limit: 30,
        )).data;
      }

      final dataSource = metadata.isEmpty
          ? '未知'
          : metadata.map((item) => item.sourceLabel).toSet().join('/');
      final dataAt = metadata.isEmpty
          ? null
          : metadata
                .map((item) => item.dataAt)
                .reduce((a, b) => a.isAfter(b) ? a : b);
      signals = engine.scan(
        targets: targets,
        sectorSeries: sectorSeries,
        rules: rules,
        dataSource: dataSource,
        dataAt: dataAt,
      );
      signalHistory = await _signalRepository.appendDeduplicated(
        signalHistory,
        signals,
        cooldownMinutes: settings.monitor.cooldownMinutes,
      );
      lastScanAt = DateTime.now();
    } catch (e) {
      lastError = e.toString();
    } finally {
      loadingSignals = false;
      notifyListeners();
    }
  }

  Future<List<Candle>> klines(String code) async =>
      (await api.fetchKlines(code, limit: 120)).data;

  Future<MarketDataResult<IntradaySnapshot>> intraday(String code) =>
      api.fetchIntraday(code);

  Future<List<TradeSignal>> scanOne(String code) async {
    final meta = metaOf(code);
    final result = await api.fetchKlines(code, limit: 120);
    final sectorSeries = <String, List<Candle>>{};
    for (final e in SectorProxy.proxies.entries) {
      sectorSeries[e.key] = (await api.fetchKlines(e.value, limit: 30)).data;
    }
    return engine.scan(
      targets: [(stock: meta, candles: result.data)],
      sectorSeries: sectorSeries,
      rules: rules,
      dataSource: result.meta.sourceLabel,
      dataAt: result.meta.dataAt,
    );
  }

  Future<List<TradeSignal>> previewRule(
    RuleDefinition rule, {
    String? code,
  }) async {
    final targetCode = code ?? (allCodes.isEmpty ? '600519' : allCodes.first);
    final meta = metaOf(targetCode);
    final result = await api.fetchKlines(targetCode, limit: 120);
    final sectorSeries = <String, List<Candle>>{};
    if (rule.kind == RuleKind.sectorCorrelation) {
      for (final entry in SectorProxy.proxies.entries) {
        sectorSeries[entry.key] = (await api.fetchKlines(
          entry.value,
          limit: 30,
        )).data;
      }
    }
    return engine.scan(
      targets: [(stock: meta, candles: result.data)],
      sectorSeries: sectorSeries,
      rules: [rule.copyWith(enabled: true)],
      dataSource: result.meta.sourceLabel,
      dataAt: result.meta.dataAt,
    );
  }

  Holding? holdingOf(String code) =>
      holdings.where((item) => item.code == code).firstOrNull;

  Future<AiStockAnalysis> analyzeStock(String code) async {
    final token = await _tokenRepository.read();
    final quote =
        quotes[code] ??
        (await api.fetchQuoteData(
          code,
          name: metaOf(code).name,
          sector: metaOf(code).sector,
        )).data;
    final daily = await api.fetchKlines(code, limit: 60);
    List<Candle> intradayBars = const [];
    try {
      intradayBars = (await api.fetchIntraday(code)).data.bars;
    } catch (_) {
      // 大模型仍可仅基于日线和规则解释。
    }
    final oneSignals = await scanOne(code);
    return llmService.analyzeStock(
      config: settings.llm,
      token: token,
      quote: quote,
      dailyCandles: daily.data,
      intradayBars: intradayBars,
      signals: oneSignals,
      holding: holdingOf(code),
    );
  }

  Future<RuleOptimizationDraft> optimizeRule(RuleDefinition rule) async {
    final token = await _tokenRepository.read();
    return llmService.optimizeRule(
      config: settings.llm,
      token: token,
      rule: rule,
    );
  }

  Future<void> requestNotificationPermission() async {
    await NotificationService.instance.requestPermission();
  }

  Future<void> showTestNotification() =>
      NotificationService.instance.showTest();

  Future<List<TradeSignal>> checkIntradayNow() => monitor.checkNow(force: true);

  void _configureMonitor() {
    monitor.configure(
      settings: settings.monitor,
      targetsProvider: _monitorTargets,
      onSignals: _handleMonitorSignals,
    );
  }

  List<WatchStock> _monitorTargets() {
    final targets = <WatchStock>[
      if (settings.monitor.monitorHoldings)
        ...holdings.map(
          (holding) => WatchStock(
            code: holding.code,
            name: holding.name,
            sector: holding.sector,
          ),
        ),
      if (settings.monitor.monitorWatchlist) ...watchlist,
    ];
    return <String, WatchStock>{
      for (final stock in targets) stock.code: stock,
    }.values.toList();
  }

  Future<void> _handleMonitorSignals(List<TradeSignal> incoming) async {
    final previousIds = signalHistory.map((item) => item.id).toSet();
    signalHistory = await _signalRepository.appendDeduplicated(
      signalHistory,
      incoming,
      cooldownMinutes: settings.monitor.cooldownMinutes,
    );
    signals = [
      ...incoming,
      ...signals.where(
        (old) => !incoming.any(
          (fresh) =>
              fresh.code == old.code && fresh.disciplineId == old.disciplineId,
        ),
      ),
    ];
    if (settings.notificationsEnabled) {
      final hour = DateTime.now().hour;
      final quiet =
          settings.monitor.quietHoursStart > settings.monitor.quietHoursEnd
          ? hour >= settings.monitor.quietHoursStart ||
                hour < settings.monitor.quietHoursEnd
          : hour >= settings.monitor.quietHoursStart &&
                hour < settings.monitor.quietHoursEnd;
      if (!quiet) {
        for (final signal in signalHistory.where(
          (item) =>
              !previousIds.contains(item.id) &&
              item.score >= settings.monitor.minimumSignalScore,
        )) {
          await NotificationService.instance.showSignal(signal);
        }
      }
    }
    notifyListeners();
  }

  void _onMonitorChanged() => notifyListeners();

  @override
  void dispose() {
    monitor.removeListener(_onMonitorChanged);
    monitor.dispose();
    super.dispose();
  }
}

/// 板块代表股
class SectorProxy {
  static const proxies = {'银行': '000001', '证券': '600030', '科技': '002230'};
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
