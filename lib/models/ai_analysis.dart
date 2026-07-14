class AiStockAnalysis {
  const AiStockAnalysis({
    required this.summary,
    required this.riskLevel,
    required this.disciplineExplanation,
    required this.conflicts,
    required this.observations,
    required this.disclaimer,
    required this.generatedAt,
  });

  final String summary;
  final String riskLevel;
  final List<String> disciplineExplanation;
  final List<String> conflicts;
  final List<String> observations;
  final String disclaimer;
  final DateTime generatedAt;

  factory AiStockAnalysis.fromJson(Map<String, dynamic> json) =>
      AiStockAnalysis(
        summary: json['summary'] as String? ?? '模型未返回摘要',
        riskLevel: json['riskLevel'] as String? ?? '未知',
        disciplineExplanation: _strings(json['disciplineExplanation']),
        conflicts: _strings(json['conflicts']),
        observations: _strings(json['observations']),
        disclaimer:
            json['disclaimer'] as String? ?? '该内容由大模型生成，仅用于纪律解释，不构成投资建议。',
        generatedAt: DateTime.now(),
      );
}

class RuleOptimizationDraft {
  const RuleOptimizationDraft({
    required this.optimizedSummary,
    required this.optimizedDescription,
    required this.parameterSuggestions,
    required this.reasons,
  });

  final String optimizedSummary;
  final String optimizedDescription;
  final Map<String, double> parameterSuggestions;
  final List<String> reasons;

  factory RuleOptimizationDraft.fromJson(Map<String, dynamic> json) {
    final raw = (json['parameterSuggestions'] as Map?) ?? const {};
    return RuleOptimizationDraft(
      optimizedSummary: json['optimizedSummary'] as String? ?? '',
      optimizedDescription: json['optimizedDescription'] as String? ?? '',
      parameterSuggestions: raw.map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      ),
      reasons: _strings(json['reasons']),
    );
  }
}

List<String> _strings(dynamic value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];
