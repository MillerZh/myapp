class StockQuote {
  const StockQuote({
    required this.code,
    required this.name,
    required this.price,
    required this.changePct,
    required this.changeAmount,
    this.open = 0,
    this.high = 0,
    this.low = 0,
    this.preClose = 0,
    this.volume = 0,
    this.amount = 0,
    this.sector,
  });

  final String code;
  final String name;
  final double price;
  final double changePct;
  final double changeAmount;
  final double open;
  final double high;
  final double low;
  final double preClose;
  final double volume;
  final double amount;
  final String? sector;

  String get displayCode => code.length == 6 ? code : code.padLeft(6, '0');

  /// 东财 secid：沪市 1.xxxxxx，深市 0.xxxxxx。
  String get eastMoneySecId {
    final c = displayCode;
    if (c.startsWith('6') || c.startsWith('9')) return '1.$c';
    return '0.$c';
  }
}

class WatchStock {
  const WatchStock({required this.code, required this.name, this.sector});

  final String code;
  final String name;
  final String? sector;

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    if (sector != null) 'sector': sector,
  };

  factory WatchStock.fromJson(Map<String, dynamic> json) => WatchStock(
    code: json['code'] as String,
    name: json['name'] as String,
    sector: json['sector'] as String?,
  );
}

class Holding {
  const Holding({
    required this.code,
    required this.name,
    required this.shares,
    required this.costPrice,
    this.sector,
  });

  final String code;
  final String name;
  final double shares;
  final double costPrice;
  final String? sector;

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'shares': shares,
    'costPrice': costPrice,
    if (sector != null) 'sector': sector,
  };

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
    code: json['code'] as String,
    name: json['name'] as String,
    shares: (json['shares'] as num).toDouble(),
    costPrice: (json['costPrice'] as num).toDouble(),
    sector: json['sector'] as String?,
  );
}
