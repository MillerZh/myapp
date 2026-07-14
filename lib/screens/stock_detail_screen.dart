import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_analysis.dart';
import '../models/candle.dart';
import '../models/signal.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_card.dart';

class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({super.key, required this.code});

  final String code;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  late Future<
    ({List<Candle> candles, List<Candle> intraday, List<TradeSignal> signals})
  >
  _future;
  AiStockAnalysis? _analysis;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<
    ({List<Candle> candles, List<Candle> intraday, List<TradeSignal> signals})
  >
  _load() async {
    final state = context.read<AppState>();
    final candles = await state.klines(widget.code);
    final signals = await state.scanOne(widget.code);
    List<Candle> intraday = const [];
    try {
      intraday = (await state.intraday(widget.code)).data.bars;
    } catch (_) {
      // 日线详情仍可使用，页面会明确无分时数据。
    }
    return (candles: candles, intraday: intraday, signals: signals);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final meta = state.metaOf(widget.code);
    final quote = state.quotes[widget.code];

    return Scaffold(
      appBar: AppBar(title: Text('${meta.name}  ${meta.code}')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final candles = data.candles;
          final intraday = data.intraday;
          final last = candles.isEmpty ? null : candles.last;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (quote != null || last != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (quote?.price ?? last!.close).toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: (quote?.changePct ?? last!.pctChange) >= 0
                              ? AppTheme.buy
                              : const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quote == null
                            ? '昨收参考 · 日K收盘 ${last!.pctChange.toStringAsFixed(2)}%'
                            : '${quote.changePct >= 0 ? '+' : ''}${quote.changePct.toStringAsFixed(2)}%'
                                  '  ${quote.changeAmount >= 0 ? '+' : ''}${quote.changeAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      if (meta.sector != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '板块：${meta.sector}',
                          style: const TextStyle(color: AppTheme.slate),
                        ),
                      ],
                      if (state.quoteMetadata[widget.code] case final source?)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '数据：${source.sourceLabel}'
                            '${source.isStale ? '（缓存已过期）' : ''}'
                            ' · ${source.dataAt}',
                            style: TextStyle(
                              color: source.isStale
                                  ? AppTheme.accent
                                  : AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (last != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            _kv('开', last.open),
                            _kv('高', last.high),
                            _kv('低', last.low),
                            _kv('收', last.close),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                '迷你走势（近60日收盘）',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: candles.length < 2
                    ? const Center(child: Text('暂无K线'))
                    : CustomPaint(
                        painter: _SparklinePainter(
                          candles
                              .sublist(
                                candles.length > 60 ? candles.length - 60 : 0,
                              )
                              .map((c) => c.close)
                              .toList(),
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
              const SizedBox(height: 20),
              const Text('今日分时', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: intraday.length < 2
                    ? const Center(
                        child: Text(
                          '暂无真实分时数据',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                      )
                    : CustomPaint(
                        painter: _SparklinePainter(
                          intraday.map((bar) => bar.close).toList(),
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                '命中纪律（${data.signals.length}）',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (data.signals.isEmpty)
                const Text('当前未触发规则', style: TextStyle(color: AppTheme.muted))
              else
                ...data.signals.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SignalCard(signal: s),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'AI纪律解读',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _analyzing ? null : _runAi,
                    icon: _analyzing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_analyzing ? '分析中' : '综合分析'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_analysis == null)
                const Text(
                  '配置大模型后，可基于真实行情、持仓成本和已命中纪律生成结构化解释。',
                  style: TextStyle(color: AppTheme.muted),
                )
              else
                _AiAnalysisCard(analysis: _analysis!),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, double v) {
    return Text(
      '$k ${v.toStringAsFixed(2)}',
      style: const TextStyle(color: AppTheme.muted, fontSize: 13),
    );
  }

  Future<void> _runAi() async {
    final state = context.read<AppState>();
    if (!state.settings.llm.isConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在设置中配置并启用大模型。')));
      return;
    }
    setState(() => _analyzing = true);
    try {
      final result = await state.analyzeStock(widget.code);
      if (mounted) setState(() => _analysis = result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }
}

class _AiAnalysisCard extends StatelessWidget {
  const _AiAnalysisCard({required this.analysis});

  final AiStockAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '风险等级：${analysis.riskLevel}',
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(analysis.summary, style: const TextStyle(height: 1.45)),
            if (analysis.disciplineExplanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('纪律解释', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final item in analysis.disciplineExplanation)
                Text('· $item'),
            ],
            if (analysis.conflicts.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('冲突信号', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final item in analysis.conflicts) Text('· $item'),
            ],
            if (analysis.observations.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('待观察', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final item in analysis.observations) Text('· $item'),
            ],
            const SizedBox(height: 10),
            Text(
              analysis.disclaimer,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - (values[i] - minV) / span * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = AppTheme.accent.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.slate
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
