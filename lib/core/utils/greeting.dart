enum GreetingPeriod {
  morning,
  afternoon,
  evening,
  night,
}

/// Pure function to determine greeting period from device local time.
/// Boundary specifications:
/// - 05:00 to 11:59 -> morning
/// - 12:00 to 16:59 -> afternoon
/// - 17:00 to 20:59 -> evening
/// - 21:00 to 04:59 -> night
GreetingPeriod getGreetingPeriod(DateTime dateTime) {
  final hour = dateTime.hour;

  if (hour >= 5 && hour < 12) {
    return GreetingPeriod.morning;
  } else if (hour >= 12 && hour < 17) {
    return GreetingPeriod.afternoon;
  } else if (hour >= 17 && hour < 21) {
    return GreetingPeriod.evening;
  } else {
    return GreetingPeriod.night;
  }
}

/// Extracts the first name from full name or guest name.
String extractFirstName(String? fullName) {
  if (fullName == null || fullName.trim().isEmpty) {
    return 'Grower';
  }
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.isNotEmpty ? parts.first : 'Grower';
}

/// Generates the complete localized greeting with the user's first name.
String getGreetingText({
  required DateTime dateTime,
  required String languageCode,
  required String? fullName,
}) {
  final period = getGreetingPeriod(dateTime);
  final firstName = extractFirstName(fullName);

  String phrase;
  switch (languageCode) {
    case 'si':
      switch (period) {
        case GreetingPeriod.morning:
          phrase = 'සුභ උදෑසනක්';
          break;
        case GreetingPeriod.afternoon:
          phrase = 'සුභ දහවලක්';
          break;
        case GreetingPeriod.evening:
          phrase = 'සුභ සන්ධ්යාවක්';
          break;
        case GreetingPeriod.night:
          phrase = 'සුභ රාත්රියක්';
          break;
      }
      return '$phrase, $firstName!';

    case 'ta':
      switch (period) {
        case GreetingPeriod.morning:
          phrase = 'காலை வணக்கம்';
          break;
        case GreetingPeriod.afternoon:
          phrase = 'மதிய வணக்கம்';
          break;
        case GreetingPeriod.evening:
          phrase = 'மாலை வணக்கம்';
          break;
        case GreetingPeriod.night:
          phrase = 'இரவு வணக்கம்';
          break;
      }
      return '$phrase, $firstName!';

    case 'en':
    default:
      switch (period) {
        case GreetingPeriod.morning:
          phrase = 'Good morning';
          break;
        case GreetingPeriod.afternoon:
          phrase = 'Good afternoon';
          break;
        case GreetingPeriod.evening:
          phrase = 'Good evening';
          break;
        case GreetingPeriod.night:
          phrase = 'Good night';
          break;
      }
      return '$phrase, $firstName!';
  }
}
