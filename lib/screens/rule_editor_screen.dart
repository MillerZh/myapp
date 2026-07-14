import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_analysis.dart';
import '../models/rule.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class RuleEditorScreen extends StatefulWidget {
  const RuleEditorScreen({super.key, this.rule});

  final RuleDefinition? rule;

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _summary;
  late final TextEditingController _description;
  late Map<String, double> _values;
  late List<RuleCondition> _conditions;
  bool _enabled = true;
  bool _optimizing = false;

  bool get _isNew => widget.rule == null;
  bool get _isCustom => _isNew || widget.rule!.kind == RuleKind.custom;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _name = TextEditingController(text: rule?.name ?? '');
    _summary = TextEditingController(text: rule?.summary ?? '');
    _description = TextEditingController(text: rule?.description ?? '');
    _values = Map.of(rule?.values ?? const {});
    _conditions = List.of(rule?.conditions ?? const []);
    _enabled = rule?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新增自定义纪律' : '编辑纪律'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'AI优化草稿',
              onPressed: _optimizing ? null : _optimize,
              icon: _optimizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('启用这条纪律'),
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '规则名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _summary,
            decoration: const InputDecoration(labelText: '一句话摘要'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: '执行建议/规则说明'),
            maxLines: 4,
          ),
          if (!_isCustom && rule != null) ...[
            const SizedBox(height: 20),
            const Text(
              '阈值参数',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final parameter in rule.parameters)
              _ParameterEditor(
                parameter: parameter,
                value: _values[parameter.key] ?? parameter.defaultValue,
                onChanged: (value) => _values[parameter.key] = value,
              ),
          ],
          if (_isCustom) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '全部满足以下条件时触发',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addCondition,
                  icon: const Icon(Icons.add),
                  label: const Text('添加条件'),
                ),
              ],
            ),
            if (_conditions.isEmpty)
              const Text(
                '至少添加一个量化条件；自定义规则不会执行任意代码。',
                style: TextStyle(color: AppTheme.muted),
              ),
            for (var i = 0; i < _conditions.length; i++)
              Card(
                child: ListTile(
                  title: Text(_conditionLabel(_conditions[i])),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _conditions.removeAt(i)),
                  ),
                ),
              ),
          ],
          if (rule != null && rule.history.isNotEmpty) ...[
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('历史版本（${rule.history.length}）'),
              children: rule.history.reversed
                  .map(
                    (version) => ListTile(
                      dense: true,
                      title: Text('v${version.version} · ${version.summary}'),
                      subtitle: Text(version.savedAt.toString()),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.science_outlined),
            label: const Text('用当前股票历史数据试跑'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('校验并保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final edited = _buildRule();
    try {
      await context.read<AppState>().saveRule(edited);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  RuleDefinition _buildRule() {
    final before = widget.rule;
    final id =
        before?.id ??
        'custom_${DateTime.now().millisecondsSinceEpoch.toString()}';
    return RuleDefinition(
      id: id,
      kind: before?.kind ?? RuleKind.custom,
      name: _name.text.trim(),
      summary: _summary.text.trim(),
      description: _description.text.trim(),
      enabled: _enabled,
      version: before?.version ?? 1,
      parameters: before?.parameters ?? const [],
      values: _values,
      conditions: _conditions,
      history: before?.history ?? const [],
      isBuiltIn: before?.isBuiltIn ?? false,
    );
  }

  Future<void> _preview() async {
    try {
      final state = context.read<AppState>();
      final result = await state.previewRule(_buildRule());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('规则试跑结果'),
          content: Text(
            result.isEmpty
                ? '当前组合首只股票未命中这条规则。'
                : result
                      .map((signal) => '${signal.name}：${signal.reason}')
                      .join('\n\n'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addCondition() async {
    var metric = RuleMetric.gapPercent;
    var op = RuleOperator.greaterOrEqual;
    final value = TextEditingController(text: '3');
    final result = await showDialog<RuleCondition>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('添加量化条件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<RuleMetric>(
                initialValue: metric,
                decoration: const InputDecoration(labelText: '指标'),
                items: RuleMetric.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_metricLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next != null) setDialog(() => metric = next);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<RuleOperator>(
                initialValue: op,
                decoration: const InputDecoration(labelText: '运算符'),
                items: RuleOperator.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_operatorLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next != null) setDialog(() => op = next);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: value,
                decoration: const InputDecoration(labelText: '阈值'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(value.text);
                if (parsed == null) return;
                Navigator.pop(
                  dialogContext,
                  RuleCondition(metric: metric, operator: op, value: parsed),
                );
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    value.dispose();
    if (result != null) setState(() => _conditions.add(result));
  }

  Future<void> _optimize() async {
    final state = context.read<AppState>();
    if (!state.settings.llm.isConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在设置中配置并启用大模型。')));
      return;
    }
    setState(() => _optimizing = true);
    try {
      final draft = await state.optimizeRule(widget.rule!);
      if (!mounted) return;
      final apply = await _showDraft(draft);
      if (apply == true) {
        setState(() {
          if (draft.optimizedSummary.isNotEmpty) {
            _summary.text = draft.optimizedSummary;
          }
          if (draft.optimizedDescription.isNotEmpty) {
            _description.text = draft.optimizedDescription;
          }
          _values.addAll(draft.parameterSuggestions);
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _optimizing = false);
    }
  }

  Future<bool?> _showDraft(RuleOptimizationDraft draft) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI优化草稿'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(draft.optimizedSummary),
              const SizedBox(height: 8),
              Text(draft.optimizedDescription),
              const SizedBox(height: 8),
              for (final entry in draft.parameterSuggestions.entries)
                Text('${entry.key} → ${entry.value}'),
              for (final reason in draft.reasons) Text('· $reason'),
              const SizedBox(height: 8),
              const Text(
                '草稿尚未生效；应用后仍需点击“校验并保存”。',
                style: TextStyle(color: AppTheme.accent),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('放弃'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('应用到编辑器'),
          ),
        ],
      ),
    );
  }

  String _conditionLabel(RuleCondition condition) =>
      '${_metricLabel(condition.metric)} '
      '${_operatorLabel(condition.operator)} ${condition.value}';
}

class _ParameterEditor extends StatefulWidget {
  const _ParameterEditor({
    required this.parameter,
    required this.value,
    required this.onChanged,
  });

  final RuleParameter parameter;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_ParameterEditor> createState() => _ParameterEditorState();
}

class _ParameterEditorState extends State<_ParameterEditor> {
  late double _value = widget.value;

  @override
  Widget build(BuildContext context) {
    final p = widget.parameter;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${_value.toStringAsFixed(2)}${p.unit}'),
              ],
            ),
            Slider(
              value: _value.clamp(p.min, p.max),
              min: p.min,
              max: p.max,
              divisions: 100,
              onChanged: (value) {
                setState(() => _value = value);
                widget.onChanged(value);
              },
            ),
            Text(
              '${p.description}（范围 ${p.min}–${p.max}${p.unit}）',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

String _metricLabel(RuleMetric metric) => switch (metric) {
  RuleMetric.gapPercent => '跳空幅度(%)',
  RuleMetric.openGainPercent => '当日涨幅(%)',
  RuleMetric.pullbackPercent => '高点回落(%)',
  RuleMetric.relativeVolume => '相对量能(倍)',
  RuleMetric.closeBelowMaPercent => '均线下方(%)',
  RuleMetric.dropFromPeakPercent => '阶段回撤(%)',
  RuleMetric.upperShadowRatio => '上影线比例(%)',
  RuleMetric.lowerShadowRatio => '下影线比例(%)',
  RuleMetric.bodyRatio => '实体比例(%)',
  RuleMetric.consecutiveYangDays => '连续阳线(天)',
  RuleMetric.threeDayGainPercent => '三日涨幅(%)',
};

String _operatorLabel(RuleOperator op) => switch (op) {
  RuleOperator.greaterThan => '大于',
  RuleOperator.greaterOrEqual => '大于等于',
  RuleOperator.lessThan => '小于',
  RuleOperator.lessOrEqual => '小于等于',
  RuleOperator.equal => '等于',
};
