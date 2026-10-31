import 'package:flutter/material.dart';

class BilingualText extends StatelessWidget {
  final String textEn;
  final String textSi;
  final String? textTa;
  final TextStyle? primaryStyle;
  final TextStyle? secondaryStyle;
  final CrossAxisAlignment crossAxisAlignment;

  const BilingualText({
    super.key,
    required this.textEn,
    required this.textSi,
    this.textTa,
    this.primaryStyle,
    this.secondaryStyle,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final defaultStyle = primaryStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.35,
        );

    String displayText;
    if (lang == 'si') {
      displayText = textSi.trim().isNotEmpty ? textSi : textEn;
    } else if (lang == 'ta') {
      displayText = (textTa != null && textTa!.trim().isNotEmpty)
          ? textTa!
          : (textEn.trim().isNotEmpty ? textEn : textSi);
    } else {
      displayText = textEn.trim().isNotEmpty ? textEn : textSi;
    }

    return Text(
      displayText,
      style: defaultStyle,
    );
  }
}
