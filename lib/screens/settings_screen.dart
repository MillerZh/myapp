import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../services/app_state.dart';
import '../services/stock_api_service.dart';
import '../theme/app_theme.dart';
import 'monitor_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const ListTile(
            title: Text('数据源', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('东财公开接口无需 Token；Web 遇 CORS 请切演示数据。'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<StockDataSource>(
              segments: const [
                ButtonSegment(
                  value: StockDataSource.eastmoney,
                  label: Text('东财公开'),
                  icon: Icon(Icons.cloud_outlined),
                ),
                ButtonSegment(
                  value: StockDataSource.mock,
                  label: Text('演示数据'),
                  icon: Icon(Icons.science_outlined),
                ),
              ],
              selected: {state.apiConfig.source},
              onSelectionChanged: (set) {
                state.setDataSource(set.first);
              },
            ),
          ),
          const ListTile(
            dense: true,
            title: Text('东财：实时报价 + 日 K（Android/iOS 推荐）'),
            subtitle: Text('演示：本地合成 K 线，便于 Web/离线调试'),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('信号通知'),
            subtitle: const Text('按最低信号等级和免打扰时段显示本地通知'),
            value: state.settings.notificationsEnabled,
            onChanged: (value) async {
              if (value) await state.requestNotificationPermission();
              await state.updateSettings(
                state.settings.copyWith(notificationsEnabled: value),
              );
            },
          ),
          ListTile(
            title: const Text('发送测试通知'),
            subtitle: const Text('验证系统权限与纪律信号通知渠道'),
            trailing: const Icon(Icons.notifications_active_outlined),
            onTap: () async {
              await state.requestNotificationPermission();
              await state.showTestNotification();
            },
          ),
          ListTile(
            title: const Text('开盘监控与阈值'),
            subtitle: Text(
              state.settings.monitor.enabled
                  ? '已开启 · 09:30–09:${(30 + state.settings.monitor.windowEndMinute).toString().padLeft(2, '0')}'
                  : '未开启',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MonitorScreen())),
          ),
          const Divider(),
          _LlmSettingsCard(state: state),
          const Divider(),
          ListTile(
            title: const Text('恢复演示自选与持仓'),
            subtitle: const Text('覆盖当前本地列表'),
            trailing: const Icon(Icons.restore),
            onTap: () async {
              await state.resetDemoPortfolio();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已恢复演示组合')));
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '免责声明：本应用信号及大模型内容仅供学习与辅助决策，不构成投资建议。'
              '真实行情失败时不会静默混入演示数据；后台监控受手机系统调度限制。',
              style: TextStyle(
                color: AppTheme.muted,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LlmSettingsCard extends StatefulWidget {
  const _LlmSettingsCard({required this.state});

  final AppState state;

  @override
  State<_LlmSettingsCard> createState() => _LlmSettingsCardState();
}

class _LlmSettingsCardState extends State<_LlmSettingsCard> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  final TextEditingController _token = TextEditingController();
  bool _enabled = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final config = widget.state.settings.llm;
    _baseUrl = TextEditingController(text: config.baseUrl);
    _model = TextEditingController(text: config.model);
    _enabled = config.enabled;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _token.dispose();
    super.dispose();
  }

  LlmConfig get _config => LlmConfig(
    baseUrl: _baseUrl.text.trim(),
    model: _model.text.trim(),
    timeoutSeconds: widget.state.settings.llm.timeoutSeconds,
    enabled: _enabled,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '大模型（OpenAI兼容）',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            '用于纪律解释和规则草稿，不会直接修改已启用规则。',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          if (kIsWeb)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Web提示：浏览器无法像手机钥匙串一样保护长期Token，建议填写你自己的HTTPS代理地址。',
                style: TextStyle(color: AppTheme.accent, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            title: const Text('启用大模型功能'),
            onChanged: (value) => setState(() => _enabled = value),
          ),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.example.com/v1',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型名',
              hintText: '例如 gpt-4.1-mini',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _token,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Token（留空则保留已保存Token）',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('保存配置'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _test,
                child: Text(_busy ? '测试中…' : '连接测试'),
              ),
              TextButton(
                onPressed: _busy ? null : _clearToken,
                child: const Text('清除Token'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String> _effectiveToken() async {
    if (_token.text.trim().isNotEmpty) return _token.text.trim();
    return widget.state.readLlmToken();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.state.updateLlmConfig(
        _config,
        token: _token.text.trim().isEmpty ? null : _token.text,
      );
      _token.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('大模型配置已保存，Token已安全存储')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      await widget.state.testLlmConnection(
        config: _config,
        token: await _effectiveToken(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接成功')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearToken() async {
    await widget.state.clearLlmToken();
    _token.clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Token已清除')));
    }
  }
}
