import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/demo_data.dart';
import '../disciplines/default_rules.dart';
import '../models/app_settings.dart';
import '../models/market_data.dart';
import '../models/rule.dart';
import '../models/signal.dart';
import '../models/stock.dart';

class PortfolioRepository {
  static const _watchKey = 'watchlist_v1';
  static const _holdingKey = 'holdings_v1';

  Future<({List<WatchStock> watchlist, List<Holding> holdings})> load() async {
    final prefs = await SharedPreferences.getInstance();
    final watchRaw = prefs.getString(_watchKey);
    final holdingRaw = prefs.getString(_holdingKey);
    return (
      watchlist: watchRaw == null
          ? List.of(DemoData.seedWatchlist)
          : (jsonDecode(watchRaw) as List)
                .map(
                  (item) => WatchStock.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(),
      holdings: holdingRaw == null
          ? List.of(DemoData.seedHoldings)
          : (jsonDecode(holdingRaw) as List)
                .map(
                  (item) =>
                      Holding.fromJson(Map<String, dynamic>.from(item as Map)),
                )
                .toList(),
    );
  }

  Future<void> save(List<WatchStock> watchlist, List<Holding> holdings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(
        _watchKey,
        jsonEncode(watchlist.map((item) => item.toJson()).toList()),
      ),
      prefs.setString(
        _holdingKey,
        jsonEncode(holdings.map((item) => item.toJson()).toList()),
      ),
    ]);
  }
}

class SettingsRepository {
  static const _settingsKey = 'app_settings_v2';
  static const _legacySourceKey = 'data_source_v1';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw != null) {
      return AppSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    }
    final legacy = prefs.getString(_legacySourceKey);
    final migrated = AppSettings(
      dataSource: legacy == 'mock'
          ? StockDataSource.mock
          : StockDataSource.eastmoney,
    );
    await save(migrated);
    return migrated;
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}

class RuleRepository {
  static const _key = 'discipline_rules_v2';

  Future<List<RuleDefinition>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return DefaultRules.create();
    try {
      final loaded = (jsonDecode(raw) as List)
          .map(
            (item) =>
                RuleDefinition.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      return _mergeNewDefaults(loaded);
    } catch (_) {
      return DefaultRules.create();
    }
  }

  Future<void> saveAll(List<RuleDefinition> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(rules.map((item) => item.toJson()).toList()),
    );
  }

  RuleDefinition createNextVersion(
    RuleDefinition before,
    RuleDefinition edited,
  ) {
    final nextVersion = before.version + 1;
    return edited.copyWith(
      version: nextVersion,
      history: [
        ...before.history,
        RuleVersion(
          version: before.version,
          savedAt: DateTime.now(),
          values: Map.of(before.values),
          summary: before.summary,
        ),
      ],
    );
  }

  String exportJson(List<RuleDefinition> rules) => const JsonEncoder.withIndent(
    '  ',
  ).convert(rules.map((item) => item.toJson()).toList());

  List<RuleDefinition> importJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('规则 JSON 顶层必须是数组');
    final rules = decoded
        .map(
          (item) =>
              RuleDefinition.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final errors = rules.expand((item) => item.validate()).toList();
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    return rules;
  }

  List<RuleDefinition> _mergeNewDefaults(List<RuleDefinition> loaded) {
    final ids = loaded.map((item) => item.id).toSet();
    return [
      ...loaded,
      ...DefaultRules.create().where((item) => !ids.contains(item.id)),
    ];
  }
}

class SignalRepository {
  static const _key = 'signal_history_v2';
  static const maxCount = 500;

  Future<List<TradeSignal>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map(
            (item) =>
                TradeSignal.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<TradeSignal>> appendDeduplicated(
    List<TradeSignal> current,
    List<TradeSignal> incoming, {
    required int cooldownMinutes,
  }) async {
    final next = List<TradeSignal>.of(current);
    for (final signal in incoming) {
      final duplicate = next.any(
        (old) =>
            old.code == signal.code &&
            old.disciplineId == signal.disciplineId &&
            old.title == signal.title &&
            signal.triggeredAt.difference(old.triggeredAt).abs() <
                Duration(minutes: cooldownMinutes),
      );
      if (!duplicate) next.insert(0, signal);
    }
    if (next.length > maxCount) next.removeRange(maxCount, next.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return next;
  }
}

class SecureTokenRepository {
  static const _tokenKey = 'llm_api_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<String> read() async => await _storage.read(key: _tokenKey) ?? '';

  Future<void> write(String token) async {
    if (token.trim().isEmpty) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token.trim());
    }
  }

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
