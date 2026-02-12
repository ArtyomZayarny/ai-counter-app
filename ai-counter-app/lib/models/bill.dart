class Bill {
  final String id;
  final String meterId;
  final String readingFromId;
  final String readingToId;
  final double tariffUsed;
  final String currency;
  final double consumedUnits;
  final double totalCost;
  final DateTime periodStart;
  final DateTime periodEnd;

  Bill({
    required this.id,
    required this.meterId,
    required this.readingFromId,
    required this.readingToId,
    required this.tariffUsed,
    required this.currency,
    required this.consumedUnits,
    required this.totalCost,
    required this.periodStart,
    required this.periodEnd,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as String,
      meterId: json['meter_id'] as String,
      readingFromId: json['reading_from_id'] as String,
      readingToId: json['reading_to_id'] as String,
      tariffUsed: (json['tariff_used'] as num).toDouble(),
      currency: json['currency'] as String,
      consumedUnits: (json['consumed_units'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
    );
  }
}
