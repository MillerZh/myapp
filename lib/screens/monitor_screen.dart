import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_card.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final monitor = state.monitor;
    final settings = state.settings.monitor;
    final intraday = state.signalHistory
        .where((signal) => signal.isIntraday)
        .take(20)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('开盘监控中心'),
        actions: [
          IconButton(
            tooltip: '立即检查',
            onPressed: monitor.isChecking
                ? null
                : () => state.checkIntradayNow(),
            icon: monitor.isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.ink, AppTheme.slate],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      monitor.isRunning
                          ? Icons.sensors
                          : Icons.sensors_off_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      monitor.isRunning ? '监控已开启' : '监控未开启',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '窗口 09:${(30 + settings.windowStartMinute).toString().padLeft(2, '0')}'
                  '–09:${(30 + settings.windowEndMinute).toString().padLeft(2, '0')}'
                  ' · 每${settings.pollSeconds}秒 · ${monitor.lastDataSource ?? '等待行情'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (monitor.lastCheckedAt != null)
                  Text(
                    '最近检查 ${DateFormat('MM-dd HH:mm:ss').format(monitor.lastCheckedAt!)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          if (monitor.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                monitor.lastError!,
                style: const TextStyle(color: AppTheme.buy),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.enabled,
            title: const Text('启用开盘15–20分钟监控'),
            subtitle: const Text('前台按秒轮询；后台由系统约15分钟尽力调度'),
            onChanged: (value) =>
                state.updateMonitorSettings(settings.copyWith(enabled: value)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.monitorHoldings,
            title: const Text('监控持仓'),
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(monitorHoldings: value ?? true),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.monitorWatchlist,
            title: const Text('监控自选'),
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(monitorWatchlist: value ?? true),
            ),
          ),
          _ThresholdTile(
            title: '监控窗口',
            value: settings.windowEndMinute.toDouble(),
            min: 15,
            max: 20,
            suffix: '分钟',
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(windowEndMinute: value.round()),
            ),
          ),
          _ThresholdTile(
            title: '前台轮询间隔',
            value: settings.pollSeconds.toDouble(),
            min: 30,
            max: 120,
            suffix: '秒',
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(pollSeconds: value.round()),
            ),
          ),
          _ThresholdTile(
            title: '跳空阈值',
            value: settings.gapPercent,
            min: 1,
            max: 10,
            suffix: '%',
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(gapPercent: value),
            ),
          ),
          _ThresholdTile(
            title: '冲高阈值',
            value: settings.surgePercent,
            min: 0.5,
            max: 8,
            suffix: '%',
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(surgePercent: value),
            ),
          ),
          _ThresholdTile(
            title: '高点回落阈值',
            value: settings.pullbackPercent,
            min: 0.5,
            max: 8,
            suffix: '%',
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(pullbackPercent: value),
            ),
          ),
          _ThresholdTile(
            title: '分钟相对量能',
            value: settings.relativeVolume,
            min: 1,
            max: 5,
            suffix: '倍',
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(relativeVolume: value),
            ),
          ),
          _ThresholdTile(
            title: '同规则冷却时间',
            value: settings.cooldownMinutes.toDouble(),
            min: 15,
            max: 240,
            suffix: '分钟',
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(cooldownMinutes: value.round()),
            ),
          ),
          _ThresholdTile(
            title: '通知最低评分',
            value: settings.minimumSignalScore.toDouble(),
            min: 40,
            max: 95,
            suffix: '分',
            onChanged: (value) => state.updateMonitorSettings(
              settings.copyWith(minimumSignalScore: value.round()),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: monitor.isChecking
                ? null
                : () => state.checkIntradayNow(),
            icon: const Icon(Icons.radar),
            label: const Text('立即拉取真实分时并检查'),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '系统限制：Android/iOS 后台任务都可能延迟，iOS 尤其不保证在09:50准点运行。'
                '应用在前台时可保证设置的轮询频率；真正可靠的闭屏秒级推送仍需部署服务端并接入FCM/APNs。',
                style: TextStyle(
                  color: AppTheme.muted,
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '最近盘中信号（${intraday.length}）',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (intraday.isEmpty)
            const Text(
              '暂无盘中信号，可点击“立即检查”验证数据链路。',
              style: TextStyle(color: AppTheme.muted),
            )
          else
            ...intraday.map(
              (signal) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SignalCard(signal: signal),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThresholdTile extends StatefulWidget {
  const _ThresholdTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  State<_ThresholdTile> createState() => _ThresholdTileState();
}

class _ThresholdTileState extends State<_ThresholdTile> {
  late double value = widget.value;

  @override
  void didUpdateWidget(covariant _ThresholdTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.title)),
                Text('${value.toStringAsFixed(1)}${widget.suffix}'),
              ],
            ),
            Slider(
              value: value.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              divisions: 50,
              onChanged: (next) => setState(() => value = next),
              onChangeEnd: widget.onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
