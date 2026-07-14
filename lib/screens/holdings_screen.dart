import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/quote_tile.dart';
import 'stock_detail_screen.dart';

class HoldingsScreen extends StatelessWidget {
  const HoldingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    double totalCost = 0;
    double totalMv = 0;
    for (final h in state.holdings) {
      totalCost += h.shares * h.costPrice;
      final px = state.quotes[h.code]?.price ?? h.costPrice;
      totalMv += h.shares * px;
    }
    final pnl = totalMv - totalCost;
    final pnlPct = totalCost == 0 ? 0.0 : pnl / totalCost * 100;
    final up = pnl >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('持仓'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAdd(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshQuotes(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.ink, AppTheme.slate],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('持仓市值', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text(
                    formatMoney(totalMv),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '盈亏 ${up ? '+' : ''}${formatMoney(pnl)}（${up ? '+' : ''}${pnlPct.toStringAsFixed(2)}%）',
                    style: TextStyle(
                      color: up
                          ? const Color(0xFFFFB4A2)
                          : const Color(0xFF86EFAC),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...state.holdings.map((h) {
              final q = state.quotes[h.code];
              final px = q?.price ?? h.costPrice;
              final pnlOne = (px - h.costPrice) * h.shares;
              return Dismissible(
                key: ValueKey('h-${h.code}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: AppTheme.buy,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Text(
                    '删除',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                onDismissed: (_) => state.removeHolding(h.code),
                child: QuoteTile(
                  title: '${h.name}  ${h.code}',
                  subtitle:
                      '${h.shares.toStringAsFixed(0)}股 · 成本 ${h.costPrice.toStringAsFixed(2)}'
                      '${h.sector == null ? '' : ' · ${h.sector}'}',
                  quote: q,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        px.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${pnlOne >= 0 ? '+' : ''}${pnlOne.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: pnlOne >= 0
                              ? AppTheme.buy
                              : const Color(0xFF15803D),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StockDetailScreen(code: h.code),
                      ),
                    );
                  },
                ),
              );
            }),
            if (state.holdings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无持仓，点击右上角添加',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdd(BuildContext context) async {
    final state = context.read<AppState>();
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final sharesCtrl = TextEditingController(text: '100');
    final costCtrl = TextEditingController();
    final sectorCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加持仓'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: '代码'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              TextField(
                controller: sharesCtrl,
                decoration: const InputDecoration(labelText: '股数'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: costCtrl,
                decoration: const InputDecoration(labelText: '成本价'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: sectorCtrl,
                decoration: const InputDecoration(labelText: '板块（可选，如 科技/银行）'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.length != 6) return;
              var name = nameCtrl.text.trim();
              if (name.isEmpty) {
                try {
                  final q = await state.api.fetchQuote(code);
                  name = q.name;
                } catch (_) {
                  name = code;
                }
              }
              await state.addHolding(
                Holding(
                  code: code,
                  name: name,
                  shares: double.tryParse(sharesCtrl.text) ?? 100,
                  costPrice: double.tryParse(costCtrl.text) ?? 0,
                  sector: sectorCtrl.text.trim().isEmpty
                      ? null
                      : sectorCtrl.text.trim(),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
