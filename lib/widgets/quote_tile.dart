import 'package:flutter/material.dart';

import '../models/stock.dart';
import '../theme/app_theme.dart';

class QuoteTile extends StatelessWidget {
  const QuoteTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.quote,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final StockQuote? quote;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final up = (q?.changePct ?? 0) >= 0;
    final color = q == null
        ? AppTheme.muted
        : (up ? AppTheme.buy : const Color(0xFF15803D));

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.ink,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.muted)),
      trailing:
          trailing ??
          (q == null
              ? const Text('—', style: TextStyle(color: AppTheme.muted))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      q.price.toStringAsFixed(2),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${up ? '+' : ''}${q.changePct.toStringAsFixed(2)}%',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ],
                )),
    );
  }
}

String formatMoney(double v) {
  if (v.abs() >= 1e8) return '${(v / 1e8).toStringAsFixed(2)}亿';
  if (v.abs() >= 1e4) return '${(v / 1e4).toStringAsFixed(2)}万';
  return v.toStringAsFixed(2);
}
