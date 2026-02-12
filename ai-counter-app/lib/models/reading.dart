class Reading {
  final String id;
  final String meterId;
  final int value;
  final DateTime recordedAt;
  final DateTime createdAt;

  Reading({
    required this.id,
    required this.meterId,
    required this.value,
    required this.recordedAt,
    required this.createdAt,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] as String,
      meterId: json['meter_id'] as String,
      value: json['value'] as int,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedValue => value.toString().padLeft(5, '0');
}
