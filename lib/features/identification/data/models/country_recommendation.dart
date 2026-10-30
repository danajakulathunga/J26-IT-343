class CountryRecommendation {
  final String country;
  final double exportScore;
  final String demand;
  final double avgUnitValueUsdKg;
  final String bestWindow;
  final String qualityRequirement;

  CountryRecommendation({
    required this.country,
    required this.exportScore,
    required this.demand,
    required this.avgUnitValueUsdKg,
    required this.bestWindow,
    required this.qualityRequirement,
  });

  factory CountryRecommendation.fromJson(Map<String, dynamic> json) {
    return CountryRecommendation(
      country: json['country'] as String,
      exportScore: (json['exportScore'] as num).toDouble(),
      demand: json['demand'] as String,
      avgUnitValueUsdKg: (json['avgUnitValueUsdKg'] as num).toDouble(),
      bestWindow: json['bestWindow'] as String,
      qualityRequirement: json['qualityRequirement'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'exportScore': exportScore,
      'demand': demand,
      'avgUnitValueUsdKg': avgUnitValueUsdKg,
      'bestWindow': bestWindow,
      'qualityRequirement': qualityRequirement,
    };
  }
}
