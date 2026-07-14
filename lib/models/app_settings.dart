import 'market_data.dart';

class MonitorSettings {
  const MonitorSettings({
    this.enabled = false,
    this.monitorHoldings = true,
    this.monitorWatchlist = true,
    this.windowStartMinute = 0,
    this.windowEndMinute = 20,
    this.pollSeconds = 45,
    this.gapPercent = 3,
    this.surgePercent = 2,
    this.pullbackPercent = 1.5,
    this.relativeVolume = 1.5,
    this.cooldownMinutes = 60,
    this.minimumSignalScore = 60,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 8,
  });

  final bool enabled;
  final bool monitorHoldings;
  final bool monitorWatchlist;
  final int windowStartMinute;
  final int windowEndMinute;
  final int pollSeconds;
  final double gapPercent;
  final double surgePercent;
  final double pullbackPercent;
  final double relativeVolume;
  final int cooldownMinutes;
  final int minimumSignalScore;
  final int quietHoursStart;
  final int quietHoursEnd;

  MonitorSettings copyWith({
    bool? enabled,
    bool? monitorHoldings,
    bool? monitorWatchlist,
    int? windowStartMinute,
    int? windowEndMinute,
    int? pollSeconds,
    double? gapPercent,
    double? surgePercent,
    double? pullbackPercent,
    double? relativeVolume,
    int? cooldownMinutes,
    int? minimumSignalScore,
    int? quietHoursStart,
    int? quietHoursEnd,
  }) {
    return MonitorSettings(
      enabled: enabled ?? this.enabled,
      monitorHoldings: monitorHoldings ?? this.monitorHoldings,
      monitorWatchlist: monitorWatchlist ?? this.monitorWatchlist,
      windowStartMinute: windowStartMinute ?? this.windowStartMinute,
      windowEndMinute: windowEndMinute ?? this.windowEndMinute,
      pollSeconds: pollSeconds ?? this.pollSeconds,
      gapPercent: gapPercent ?? this.gapPercent,
      surgePercent: surgePercent ?? this.surgePercent,
      pullbackPercent: pullbackPercent ?? this.pullbackPercent,
      relativeVolume: relativeVolume ?? this.relativeVolume,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      minimumSignalScore: minimumSignalScore ?? this.minimumSignalScore,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'monitorHoldings': monitorHoldings,
    'monitorWatchlist': monitorWatchlist,
    'windowStartMinute': windowStartMinute,
    'windowEndMinute': windowEndMinute,
    'pollSeconds': pollSeconds,
    'gapPercent': gapPercent,
    'surgePercent': surgePercent,
    'pullbackPercent': pullbackPercent,
    'relativeVolume': relativeVolume,
    'cooldownMinutes': cooldownMinutes,
    'minimumSignalScore': minimumSignalScore,
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
  };

  factory MonitorSettings.fromJson(Map<String, dynamic> json) =>
      MonitorSettings(
        enabled: json['enabled'] as bool? ?? false,
        monitorHoldings: json['monitorHoldings'] as bool? ?? true,
        monitorWatchlist: json['monitorWatchlist'] as bool? ?? true,
        windowStartMinute: json['windowStartMinute'] as int? ?? 0,
        windowEndMinute: json['windowEndMinute'] as int? ?? 20,
        pollSeconds: json['pollSeconds'] as int? ?? 45,
        gapPercent: (json['gapPercent'] as num?)?.toDouble() ?? 3,
        surgePercent: (json['surgePercent'] as num?)?.toDouble() ?? 2,
        pullbackPercent: (json['pullbackPercent'] as num?)?.toDouble() ?? 1.5,
        relativeVolume: (json['relativeVolume'] as num?)?.toDouble() ?? 1.5,
        cooldownMinutes: json['cooldownMinutes'] as int? ?? 60,
        minimumSignalScore: json['minimumSignalScore'] as int? ?? 60,
        quietHoursStart: json['quietHoursStart'] as int? ?? 22,
        quietHoursEnd: json['quietHoursEnd'] as int? ?? 8,
      );
}

class LlmConfig {
  const LlmConfig({
    this.baseUrl = '',
    this.model = '',
    this.timeoutSeconds = 45,
    this.enabled = false,
  });

  final String baseUrl;
  final String model;
  final int timeoutSeconds;
  final bool enabled;

  bool get isConfigured =>
      enabled && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  LlmConfig copyWith({
    String? baseUrl,
    String? model,
    int? timeoutSeconds,
    bool? enabled,
  }) {
    return LlmConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'model': model,
    'timeoutSeconds': timeoutSeconds,
    'enabled': enabled,
  };

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
    baseUrl: json['baseUrl'] as String? ?? '',
    model: json['model'] as String? ?? '',
    timeoutSeconds: json['timeoutSeconds'] as int? ?? 45,
    enabled: json['enabled'] as bool? ?? false,
  );
}

class AppSettings {
  const AppSettings({
    this.dataSource = StockDataSource.eastmoney,
    this.notificationsEnabled = true,
    this.monitor = const MonitorSettings(),
    this.llm = const LlmConfig(),
  });

  final StockDataSource dataSource;
  final bool notificationsEnabled;
  final MonitorSettings monitor;
  final LlmConfig llm;

  AppSettings copyWith({
    StockDataSource? dataSource,
    bool? notificationsEnabled,
    MonitorSettings? monitor,
    LlmConfig? llm,
  }) {
    return AppSettings(
      dataSource: dataSource ?? this.dataSource,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      monitor: monitor ?? this.monitor,
      llm: llm ?? this.llm,
    );
  }

  Map<String, dynamic> toJson() => {
    'dataSource': dataSource.name,
    'notificationsEnabled': notificationsEnabled,
    'monitor': monitor.toJson(),
    'llm': llm.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    dataSource: StockDataSource.values.byName(
      json['dataSource'] as String? ?? StockDataSource.eastmoney.name,
    ),
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    monitor: MonitorSettings.fromJson(
      (json['monitor'] as Map<String, dynamic>?) ?? const {},
    ),
    llm: LlmConfig.fromJson((json['llm'] as Map<String, dynamic>?) ?? const {}),
  );
}
