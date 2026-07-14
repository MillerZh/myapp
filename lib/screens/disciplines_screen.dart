import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rule.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'rule_editor_screen.dart';

class DisciplinesScreen extends StatelessWidget {
  const DisciplinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.rules;
    return Scaffold(
      appBar: AppBar(
        title: const Text('纪律规则'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenu(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('导入 JSON')),
              PopupMenuItem(value: 'export', child: Text('导出 JSON')),
              PopupMenuItem(value: 'restore', child: Text('恢复内置规则')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('新增纪律'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: list.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '规则支持启停、阈值调整、版本记录和自定义条件。AI 仅生成待审核草稿，不会自动修改纪律。',
                style: TextStyle(color: AppTheme.muted, height: 1.45),
              ),
            );
          }
          final d = list[i - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                SwitchListTile(
                  value: d.enabled,
                  onChanged: (value) => state.toggleRule(d.id, value),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      Text(
                        'v${d.version}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(d.summary),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        d.isBuiltIn ? '内置规则' : '自定义规则',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (!d.isBuiltIn)
                        IconButton(
                          tooltip: '删除',
                          onPressed: () => state.deleteRule(d.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      TextButton.icon(
                        onPressed: () => _openEditor(context, d),
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('编辑/试跑'),
                      ),
                    ],
                  ),
                ),
                if (d.parameters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: d.parameters
                          .map(
                            (p) => Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                '${p.label} ${d.value(p.key).toStringAsFixed(2)}${p.unit}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, [RuleDefinition? rule]) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RuleEditorScreen(rule: rule)));
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    final state = context.read<AppState>();
    switch (value) {
      case 'export':
        await Clipboard.setData(ClipboardData(text: state.exportRules()));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('规则 JSON 已复制到剪贴板')));
        }
        return;
      case 'import':
        final controller = TextEditingController();
        final raw = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('导入规则 JSON'),
            content: TextField(
              controller: controller,
              maxLines: 12,
              decoration: const InputDecoration(hintText: '粘贴规则 JSON 数组'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('校验并导入'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (raw != null && raw.trim().isNotEmpty) {
          try {
            await state.importRules(raw);
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        }
        return;
      case 'restore':
        await state.restoreDefaultRules();
        return;
    }
  }
}
