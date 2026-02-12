class Meter {
  final String id;
  final String propertyId;
  final String utilityType;
  final String name;
  final int digitCount;

  Meter({
    required this.id,
    required this.propertyId,
    required this.utilityType,
    required this.name,
    required this.digitCount,
  });

  factory Meter.fromJson(Map<String, dynamic> json) {
    return Meter(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      utilityType: json['utility_type'] as String,
      name: json['name'] as String,
      digitCount: json['digit_count'] as int,
    );
  }
}
