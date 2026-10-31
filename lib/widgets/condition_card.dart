import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bananaguard_ai/core/api_client.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/models/scan_result.dart';
import 'package:bananaguard_ai/widgets/bilingual_text.dart';

class ConditionCard extends StatelessWidget {
  final ScanResultModel scan;
  final VoidCallback? onTap;

  const ConditionCard({
    super.key,
    required this.scan,
    this.onTap,
  });

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'disease':
        return const Color(0xFFDC2626);
      case 'defect':
        return const Color(0xFFD97706);
      case 'healthy':
      default:
        return AppConstants.primaryGreen;
    }
  }

  Color _getSeverityColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'severe':
        return AppConstants.severitySevere;
      case 'moderate':
        return AppConstants.severityModerate;
      case 'mild':
      default:
        return AppConstants.severityMild;
    }
  }

  Widget _buildFallbackIcon(Color typeColor) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: typeColor.withOpacity(0.25)),
      ),
      child: Icon(
        scan.isHealthy
            ? Icons.check_circle_outline
            : Icons.coronavirus_outlined,
        color: typeColor,
        size: 30,
      ),
    );
  }

  String _formatScanDate(String createdAt, String locale) {
    final dateTime = DateTime.tryParse(createdAt)?.toLocal();
    if (dateTime == null) return createdAt;
    return DateFormat.yMMMd(locale).add_jm().format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = _getTypeColor(scan.condition.type);
    final locale = Localizations.localeOf(context).toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Image Thumbnail / Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: scan.images.originalUrl.isNotEmpty
                      ? FutureBuilder<Uint8List>(
                          future: apiClient
                              .fetchImageBytes(scan.images.originalUrl),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.done &&
                                snapshot.hasData &&
                                snapshot.data != null &&
                                snapshot.data!.isNotEmpty) {
                              return Image.memory(
                                snapshot.data!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildFallbackIcon(typeColor),
                              );
                            }
                            return _buildFallbackIcon(typeColor);
                          },
                        )
                      : _buildFallbackIcon(typeColor),
                ),
              ),
              const SizedBox(width: 14),
              // Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Builder(builder: (context) {
                          final lang =
                              Localizations.localeOf(context).languageCode;
                          String typeLabel = scan.condition.type.toUpperCase();
                          if (lang == 'si') {
                            typeLabel = scan.condition.type.toLowerCase() ==
                                    'disease'
                                ? 'රෝගය'
                                : (scan.condition.type.toLowerCase() == 'defect'
                                    ? 'හානිය'
                                    : 'නීරෝගී');
                          } else if (lang == 'ta') {
                            typeLabel = scan.condition.type.toLowerCase() ==
                                    'disease'
                                ? 'நோய்'
                                : (scan.condition.type.toLowerCase() == 'defect'
                                    ? 'குறைபாடு'
                                    : 'ஆரோக்கியமானது');
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }),
                        if (scan.variety != null) ...[
                          const SizedBox(width: 6),
                          Builder(builder: (context) {
                            final lang =
                                Localizations.localeOf(context).languageCode;
                            return Text(
                              '• ${scan.variety!.getLocalized(lang)}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 11),
                            );
                          }),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    BilingualText(
                      textEn: scan.condition.en,
                      textSi: scan.condition.si,
                      textTa: scan.condition.getLocalized('ta'),
                      primaryStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      secondaryStyle: TextStyle(
                        fontSize: 12,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    if (scan.createdAt.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatScanDate(scan.createdAt, locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Severity Chip & Confidence
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Builder(builder: (context) {
                    final lang = Localizations.localeOf(context).languageCode;
                    if (scan.severity != null) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getSeverityColor(scan.severity?.level)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _getSeverityColor(scan.severity?.level)),
                        ),
                        child: Text(
                          scan.severity!.getLocalized(lang),
                          style: TextStyle(
                            color: _getSeverityColor(scan.severity?.level),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      );
                    } else {
                      String healthyLabel = 'Healthy';
                      if (lang == 'si') healthyLabel = 'නීරෝගී';
                      if (lang == 'ta') healthyLabel = 'ஆரோக்கியமானது';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          healthyLabel,
                          style: const TextStyle(
                            color: AppConstants.primaryGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }
                  }),
                  const SizedBox(height: 4),
                  Builder(builder: (context) {
                    final lang = Localizations.localeOf(context).languageCode;
                    String matchLabel = 'match';
                    if (lang == 'si') matchLabel = 'ගැලපීම';
                    if (lang == 'ta') matchLabel = 'பொருத்தம்';
                    return Text(
                      '${(scan.conditionConfidence * 100).toStringAsFixed(0)}% $matchLabel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.outline,
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
