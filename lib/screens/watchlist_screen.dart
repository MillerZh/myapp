import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/quote_tile.dart';
import 'stock_detail_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('自选'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAdd(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await state.refreshQuotes();
          await state.scanSignals();
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: state.watchlist.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final s = state.watchlist[i];
            return Dismissible(
              key: ValueKey('w-${s.code}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppTheme.buy,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Text('删除', style: TextStyle(color: Colors.white)),
              ),
              onDismissed: (_) => state.removeWatch(s.code),
              child: QuoteTile(
                title: '${s.name}  ${s.code}',
                subtitle: s.sector ?? '未标注板块',
                quote: state.quotes[s.code],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StockDetailScreen(code: s.code),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAdd(BuildContext context) async {
    final state = context.read<AppState>();
    final controller = TextEditingController();
    List<StockQuote> results = [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '添加自选',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: '输入代码或名称，如 600519 / 茅台',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (v) async {
                      results = await state.api.search(v);
                      setModal(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      results = await state.api.search(controller.text);
                      setModal(() {});
                    },
                    child: const Text('搜索'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: results.isEmpty
                        ? const Center(
                            child: Text(
                              '输入关键词搜索 A 股',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final q = results[i];
                              return ListTile(
                                title: Text('${q.name}  ${q.code}'),
                                onTap: () async {
                                  StockQuote detail = q;
                                  try {
                                    detail = await state.api.fetchQuote(
                                      q.code,
                                      name: q.name,
                                    );
                                  } catch (_) {
                                    // 搜索结果仍可添加，板块可在后续详情中补全。
                                  }
                                  await state.addWatch(
                                    WatchStock(
                                      code: q.code,
                                      name: q.name,
                                      sector: detail.sector,
                                    ),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
