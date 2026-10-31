import 'package:flutter/material.dart';

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    String bannerText = 'Demo mode – model not trained yet';
    if (lang == 'si') {
      bannerText = 'ආදර්ශක මාදිලිය – ආකෘතිය තවමත් පුහුණු කර නොමැත';
    } else if (lang == 'ta') {
      bannerText = 'டெமோ பயன்முறை – மாதிரி இன்னும் பயிற்சி பெறவில்லை';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFFB45309), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bannerText,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
