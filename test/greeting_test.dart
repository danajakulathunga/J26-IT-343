import 'package:flutter_test/flutter_test.dart';
import 'package:bananaguard_ai/core/utils/greeting.dart';

void main() {
  group('Greeting Boundary Tests', () {
    test('05:00 is Morning boundary', () {
      final dt = DateTime(2026, 10, 14, 5, 0);
      expect(getGreetingPeriod(dt), GreetingPeriod.morning);
      expect(getGreetingText(dateTime: dt, languageCode: 'en', fullName: 'Kasun Perera'), 'Good morning, Kasun!');
      expect(getGreetingText(dateTime: dt, languageCode: 'si', fullName: 'Kasun Perera'), 'සුභ උදෑසනක්, Kasun!');
      expect(getGreetingText(dateTime: dt, languageCode: 'ta', fullName: 'Kasun Perera'), 'காலை வணக்கம், Kasun!');
    });

    test('11:59 is Morning boundary', () {
      final dt = DateTime(2026, 10, 14, 11, 59);
      expect(getGreetingPeriod(dt), GreetingPeriod.morning);
    });

    test('12:00 is Afternoon boundary', () {
      final dt = DateTime(2026, 10, 14, 12, 0);
      expect(getGreetingPeriod(dt), GreetingPeriod.afternoon);
      expect(getGreetingText(dateTime: dt, languageCode: 'en', fullName: 'Nimal Silva'), 'Good afternoon, Nimal!');
      expect(getGreetingText(dateTime: dt, languageCode: 'si', fullName: 'Nimal Silva'), 'සුභ දහවලක්, Nimal!');
      expect(getGreetingText(dateTime: dt, languageCode: 'ta', fullName: 'Nimal Silva'), 'மதிய வணக்கம், Nimal!');
    });

    test('16:59 is Afternoon boundary', () {
      final dt = DateTime(2026, 10, 14, 16, 59);
      expect(getGreetingPeriod(dt), GreetingPeriod.afternoon);
    });

    test('17:00 is Evening boundary', () {
      final dt = DateTime(2026, 10, 14, 17, 0);
      expect(getGreetingPeriod(dt), GreetingPeriod.evening);
      expect(getGreetingText(dateTime: dt, languageCode: 'en', fullName: 'Amara'), 'Good evening, Amara!');
      expect(getGreetingText(dateTime: dt, languageCode: 'si', fullName: 'Amara'), 'සුභ සන්ධ්යාවක්, Amara!');
      expect(getGreetingText(dateTime: dt, languageCode: 'ta', fullName: 'Amara'), 'மாலை வணக்கம், Amara!');
    });

    test('20:59 is Evening boundary', () {
      final dt = DateTime(2026, 10, 14, 20, 59);
      expect(getGreetingPeriod(dt), GreetingPeriod.evening);
    });

    test('21:00 is Night boundary', () {
      final dt = DateTime(2026, 10, 14, 21, 0);
      expect(getGreetingPeriod(dt), GreetingPeriod.night);
      expect(getGreetingText(dateTime: dt, languageCode: 'en', fullName: 'Sunil'), 'Good night, Sunil!');
      expect(getGreetingText(dateTime: dt, languageCode: 'si', fullName: 'Sunil'), 'සුභ රාත්රියක්, Sunil!');
      expect(getGreetingText(dateTime: dt, languageCode: 'ta', fullName: 'Sunil'), 'இரவு வணக்கம், Sunil!');
    });

    test('04:59 is Night boundary', () {
      final dt = DateTime(2026, 10, 14, 4, 59);
      expect(getGreetingPeriod(dt), GreetingPeriod.night);
    });
  });

  group('First Name Extraction Tests', () {
    test('extracts first name from multi-word string', () {
      expect(extractFirstName('Kasun Bandara Perera'), 'Kasun');
      expect(extractFirstName('Nimal'), 'Nimal');
    });

    test('defaults to Grower when empty or null', () {
      expect(extractFirstName(null), 'Grower');
      expect(extractFirstName('   '), 'Grower');
    });
  });
}
