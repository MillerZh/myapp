import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/signal.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_card.dart';
import 'monitor_screen.dart';
import 'stock_detail_screen.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final displaySignals = _showHistory ? state.signalHistory : state.signals;
    final grouped = <String, List<TradeSignal>>{};
    for (final s in displaySignals) {
      grouped.putIfAbsent(s.disciplineName, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('信号 SIGNALS'),
        actions: [
          IconButton(
            tooltip: '开盘监控中心',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MonitorScreen()));
            },
            icon: const Icon(Icons.radar),
          ),
          IconButton(
            tooltip: '重新扫描',
            onPressed: state.loadingSignals ? null : () => state.scanSignals(),
            icon: state.loadingSignals
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.softWarn,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              state.loadingSignals
                  ? '正在扫描自选与持仓…'
                  : '本次扫描触发 ${state.signals.length} 条信号'
                        '${state.lastScanAt == null ? '' : ' · ${DateFormat('HH:mm:ss').format(state.lastScanAt!)}'}',
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('本次扫描')),
                ButtonSegment(value: true, label: Text('历史记录')),
              ],
              selected: {_showHistory},
              onSelectionChanged: (value) {
                setState(() => _showHistory = value.first);
              },
            ),
          ),
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '真实行情获取失败，未使用演示数据替代：${state.lastError}',
                style: const TextStyle(color: AppTheme.accent, fontSize: 12),
              ),
            ),
          Expanded(
            child: displaySignals.isEmpty && !state.loadingSignals
                ? const Center(
                    child: Text(
                      '暂无信号\n添加自选/持仓后点击刷新',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted, height: 1.5),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Text(
                            '${entry.key} · 命中 ${entry.value.length} 条',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate,
                            ),
                          ),
                        ),
                        for (final sig in entry.value) ...[
                          SignalCard(
                            signal: sig,
                            onTap: sig.code == 'SECTOR'
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StockDetailScreen(code: sig.code),
                                      ),
                                    );
                                  },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
