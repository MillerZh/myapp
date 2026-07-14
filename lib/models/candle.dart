/// 蜡烛图日 K 数据。
class Candle {
  const Candle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.amount = 0,
    this.pctChange = 0,
  });

  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double amount;
  final double pctChange;

  double get body => (close - open).abs();
  double get range => high - low;
  double get upperShadow => high - (open > close ? open : close);
  double get lowerShadow => (open < close ? open : close) - low;
  bool get isYang => close >= open;
  bool get isYin => close < open;

  Candle copyWith({
    DateTime? date,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
    double? amount,
    double? pctChange,
  }) {
    return Candle(
      date: date ?? this.date,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      amount: amount ?? this.amount,
      pctChange: pctChange ?? this.pctChange,
    );
  }
}
