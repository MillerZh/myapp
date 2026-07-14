enum RuleKind { exit, gapUp, secondHigh, sectorCorrelation, custom }

enum RuleParameterType { decimal, integer, percent, boolean }

enum RuleMetric {
  gapPercent,
  openGainPercent,
  pullbackPercent,
  relativeVolume,
  closeBelowMaPercent,
  dropFromPeakPercent,
  upperShadowRatio,
  lowerShadowRatio,
  bodyRatio,
  consecutiveYangDays,
  threeDayGainPercent,
}

enum RuleOperator { greaterThan, greaterOrEqual, lessThan, lessOrEqual, equal }

class RuleParameter {
  const RuleParameter({
    required this.key,
    required this.label,
    required this.type,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.unit,
    required this.description,
  });

  final String key;
  final String label;
  final RuleParameterType type;
  final double defaultValue;
  final double min;
  final double max;
  final String unit;
  final String description;

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    'defaultValue': defaultValue,
    'min': min,
    'max': max,
    'unit': unit,
    'description': description,
  };

  factory RuleParameter.fromJson(Map<String, dynamic> json) => RuleParameter(
    key: json['key'] as String,
    label: json['label'] as String,
    type: RuleParameterType.values.byName(json['type'] as String),
    defaultValue: (json['defaultValue'] as num).toDouble(),
    min: (json['min'] as num).toDouble(),
    max: (json['max'] as num).toDouble(),
    unit: json['unit'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}

class RuleCondition {
  const RuleCondition({
    required this.metric,
    required this.operator,
    required this.value,
  });

  final RuleMetric metric;
  final RuleOperator operator;
  final double value;

  bool evaluate(double actual) => switch (operator) {
    RuleOperator.greaterThan => actual > value,
    RuleOperator.greaterOrEqual => actual >= value,
    RuleOperator.lessThan => actual < value,
    RuleOperator.lessOrEqual => actual <= value,
    RuleOperator.equal => (actual - value).abs() < 0.000001,
  };

  Map<String, dynamic> toJson() => {
    'metric': metric.name,
    'operator': operator.name,
    'value': value,
  };

  factory RuleCondition.fromJson(Map<String, dynamic> json) => RuleCondition(
    metric: RuleMetric.values.byName(json['metric'] as String),
    operator: RuleOperator.values.byName(json['operator'] as String),
    value: (json['value'] as num).toDouble(),
  );
}

class RuleVersion {
  const RuleVersion({
    required this.version,
    required this.savedAt,
    required this.values,
    required this.summary,
  });

  final int version;
  final DateTime savedAt;
  final Map<String, double> values;
  final String summary;

  Map<String, dynamic> toJson() => {
    'version': version,
    'savedAt': savedAt.toIso8601String(),
    'values': values,
    'summary': summary,
  };

  factory RuleVersion.fromJson(Map<String, dynamic> json) => RuleVersion(
    version: json['version'] as int,
    savedAt: DateTime.parse(json['savedAt'] as String),
    values: (json['values'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ),
    summary: json['summary'] as String? ?? '',
  );
}

class RuleDefinition {
  const RuleDefinition({
    required this.id,
    required this.kind,
    required this.name,
    required this.summary,
    required this.description,
    required this.enabled,
    required this.version,
    required this.parameters,
    required this.values,
    this.conditions = const [],
    this.history = const [],
    this.isBuiltIn = true,
  });

  final String id;
  final RuleKind kind;
  final String name;
  final String summary;
  final String description;
  final bool enabled;
  final int version;
  final List<RuleParameter> parameters;
  final Map<String, double> values;
  final List<RuleCondition> conditions;
  final List<RuleVersion> history;
  final bool isBuiltIn;

  double value(String key) {
    final schema = parameters.where((item) => item.key == key).firstOrNull;
    return values[key] ?? schema?.defaultValue ?? 0;
  }

  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('规则 ID 不能为空');
    if (name.trim().isEmpty) errors.add('规则名称不能为空');
    for (final parameter in parameters) {
      final current = values[parameter.key] ?? parameter.defaultValue;
      if (current < parameter.min || current > parameter.max) {
        errors.add(
          '${parameter.label}必须在 ${parameter.min}${parameter.unit} '
          '到 ${parameter.max}${parameter.unit} 之间',
        );
      }
    }
    if (kind == RuleKind.custom && conditions.isEmpty) {
      errors.add('自定义规则至少需要一个条件');
    }
    return errors;
  }

  RuleDefinition copyWith({
    String? id,
    RuleKind? kind,
    String? name,
    String? summary,
    String? description,
    bool? enabled,
    int? version,
    List<RuleParameter>? parameters,
    Map<String, double>? values,
    List<RuleCondition>? conditions,
    List<RuleVersion>? history,
    bool? isBuiltIn,
  }) {
    return RuleDefinition(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      version: version ?? this.version,
      parameters: parameters ?? this.parameters,
      values: values ?? this.values,
      conditions: conditions ?? this.conditions,
      history: history ?? this.history,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'summary': summary,
    'description': description,
    'enabled': enabled,
    'version': version,
    'parameters': parameters.map((item) => item.toJson()).toList(),
    'values': values,
    'conditions': conditions.map((item) => item.toJson()).toList(),
    'history': history.map((item) => item.toJson()).toList(),
    'isBuiltIn': isBuiltIn,
  };

  factory RuleDefinition.fromJson(Map<String, dynamic> json) => RuleDefinition(
    id: json['id'] as String,
    kind: RuleKind.values.byName(json['kind'] as String),
    name: json['name'] as String,
    summary: json['summary'] as String? ?? '',
    description: json['description'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    version: json['version'] as int? ?? 1,
    parameters: ((json['parameters'] as List?) ?? const [])
        .map((item) => RuleParameter.fromJson(item as Map<String, dynamic>))
        .toList(),
    values: ((json['values'] as Map<String, dynamic>?) ?? const {}).map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ),
    conditions: ((json['conditions'] as List?) ?? const [])
        .map((item) => RuleCondition.fromJson(item as Map<String, dynamic>))
        .toList(),
    history: ((json['history'] as List?) ?? const [])
        .map((item) => RuleVersion.fromJson(item as Map<String, dynamic>))
        .toList(),
    isBuiltIn: json['isBuiltIn'] as bool? ?? true,
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
