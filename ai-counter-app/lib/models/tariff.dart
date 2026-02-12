class Tariff {
  final String id;
  final String meterId;
  final double pricePerUnit;
  final String currency;
  final DateTime effectiveFrom;

  Tariff({
    required this.id,
    required this.meterId,
    required this.pricePerUnit,
    required this.currency,
    required this.effectiveFrom,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) {
    return Tariff(
      id: json['id'] as String,
      meterId: json['meter_id'] as String,
      pricePerUnit: (json['price_per_unit'] as num).toDouble(),
      currency: json['currency'] as String,
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
    );
  }
}
