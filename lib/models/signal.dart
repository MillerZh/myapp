enum SignalAction { sellAll, sellHalf, reduce, watch, buyHint, sectorWarn }

enum SignalSide { sell, buy, neutral }

class TradeSignal {
  const TradeSignal({
    required this.id,
    required this.code,
    required this.name,
    required this.title,
    required this.reason,
    required this.advice,
    required this.disciplineId,
    required this.disciplineName,
    required this.action,
    required this.side,
    required this.triggeredAt,
    this.score = 0,
    this.ruleVersion = 1,
    this.dataSource = '未知',
    this.dataAt,
    this.timeframe = '日线',
    this.isIntraday = false,
    this.matchedConditions = const [],
  });

  final String id;
  final String code;
  final String name;
  final String title;
  final String reason;
  final String advice;
  final String disciplineId;
  final String disciplineName;
  final SignalAction action;
  final SignalSide side;
  final DateTime triggeredAt;
  final int score;
  final int ruleVersion;
  final String dataSource;
  final DateTime? dataAt;
  final String timeframe;
  final bool isIntraday;
  final List<String> matchedConditions;

  String get actionLabel => switch (action) {
    SignalAction.sellAll => '卖出',
    SignalAction.sellHalf => '卖出',
    SignalAction.reduce => '减仓',
    SignalAction.watch => '观察',
    SignalAction.buyHint => '买入',
    SignalAction.sectorWarn => '预警',
  };

  String get sideLabel => switch (side) {
    SignalSide.sell => '卖出',
    SignalSide.buy => '买入',
    SignalSide.neutral => '提示',
  };

  TradeSignal copyWith({
    String? id,
    String? code,
    String? name,
    String? title,
    String? reason,
    String? advice,
    String? disciplineId,
    String? disciplineName,
    SignalAction? action,
    SignalSide? side,
    DateTime? triggeredAt,
    int? score,
    int? ruleVersion,
    String? dataSource,
    DateTime? dataAt,
    String? timeframe,
    bool? isIntraday,
    List<String>? matchedConditions,
  }) {
    return TradeSignal(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      title: title ?? this.title,
      reason: reason ?? this.reason,
      advice: advice ?? this.advice,
      disciplineId: disciplineId ?? this.disciplineId,
      disciplineName: disciplineName ?? this.disciplineName,
      action: action ?? this.action,
      side: side ?? this.side,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      score: score ?? this.score,
      ruleVersion: ruleVersion ?? this.ruleVersion,
      dataSource: dataSource ?? this.dataSource,
      dataAt: dataAt ?? this.dataAt,
      timeframe: timeframe ?? this.timeframe,
      isIntraday: isIntraday ?? this.isIntraday,
      matchedConditions: matchedConditions ?? this.matchedConditions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'title': title,
    'reason': reason,
    'advice': advice,
    'disciplineId': disciplineId,
    'disciplineName': disciplineName,
    'action': action.name,
    'side': side.name,
    'triggeredAt': triggeredAt.toIso8601String(),
    'score': score,
    'ruleVersion': ruleVersion,
    'dataSource': dataSource,
    'dataAt': dataAt?.toIso8601String(),
    'timeframe': timeframe,
    'isIntraday': isIntraday,
    'matchedConditions': matchedConditions,
  };

  factory TradeSignal.fromJson(Map<String, dynamic> json) => TradeSignal(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    title: json['title'] as String,
    reason: json['reason'] as String,
    advice: json['advice'] as String,
    disciplineId: json['disciplineId'] as String,
    disciplineName: json['disciplineName'] as String,
    action: SignalAction.values.byName(json['action'] as String),
    side: SignalSide.values.byName(json['side'] as String),
    triggeredAt: DateTime.parse(json['triggeredAt'] as String),
    score: json['score'] as int? ?? 0,
    ruleVersion: json['ruleVersion'] as int? ?? 1,
    dataSource: json['dataSource'] as String? ?? '未知',
    dataAt: json['dataAt'] == null
        ? null
        : DateTime.parse(json['dataAt'] as String),
    timeframe: json['timeframe'] as String? ?? '日线',
    isIntraday: json['isIntraday'] as bool? ?? false,
    matchedConditions: ((json['matchedConditions'] as List?) ?? const [])
        .cast<String>(),
  );
}

class DisciplineInfo {
  const DisciplineInfo({
    required this.id,
    required this.name,
    required this.summary,
    required this.details,
  });

  final String id;
  final String name;
  final String summary;
  final String details;
}
