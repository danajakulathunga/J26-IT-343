class MarketAlert {
  final String type;
  final String message;
  final String country;
  final String createdAt;

  MarketAlert({
    required this.type,
    required this.message,
    required this.country,
    required this.createdAt,
  });

  factory MarketAlert.fromJson(Map<String, dynamic> json) {
    return MarketAlert(
      type: json['type'] as String,
      message: json['message'] as String,
      country: json['country'] as String,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message,
      'country': country,
      'createdAt': createdAt,
    };
  }
}
