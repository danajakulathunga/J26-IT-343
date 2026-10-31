import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/utils/greeting.dart';
import 'package:bananaguard_ai/providers/auth_provider.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';
import 'package:bananaguard_ai/providers/history_provider.dart';
import 'package:bananaguard_ai/services/scan_service.dart';
import 'package:bananaguard_ai/models/condition_info.dart';
import 'package:bananaguard_ai/widgets/condition_card.dart';
import 'package:bananaguard_ai/widgets/bottom_nav_bar.dart';
import 'package:bananaguard_ai/widgets/welcome_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;
  List<ConditionInfoModel> _libraryConditions = ConditionInfoModel.defaultConditions;
  bool _isLoadingLibrary = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      final list = await scanService.getConditionsLibrary();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _libraryConditions = list;
          _isLoadingLibrary = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_libraryConditions.isEmpty) {
            _libraryConditions = ConditionInfoModel.defaultConditions;
          }
          _isLoadingLibrary = false;
        });
      }
    }
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        break;
      case 1:
        ref.read(historyProvider.notifier).loadHistory();
        context.push('/history');
        break;
      case 2:
        context.push('/notifications');
        break;
      case 3:
        context.push('/profile');
        break;
    }
  }

  void _startScan() {
    context.push('/scan-capture');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final currentLocale = ref.watch(localeProvider);
    final historyState = ref.watch(historyProvider);

    // Compute localized greeting
    final now = DateTime.now();
    final greeting = getGreetingText(
      dateTime: now,
      languageCode: currentLocale.languageCode,
      fullName: authState.user?.fullName,
    );

    final recentScans = historyState.scans.take(3).toList();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // App Icon Badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.primaryGreen.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppConstants.accentYellow,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // App Title & Tag
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'BananaGuard AI',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryGreen.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Pathology & Severity Diagnostics',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Language Switcher Chip
                  InkWell(
                    onTap: () {
                      final next = currentLocale.languageCode == 'en'
                          ? 'si'
                          : (currentLocale.languageCode == 'si' ? 'ta' : 'en');
                      ref.read(localeProvider.notifier).setLocale(next);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 16, color: AppConstants.primaryGreen),
                          const SizedBox(width: 5),
                          Text(
                            currentLocale.languageCode.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Settings Button
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    tooltip: 'Settings',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(historyProvider.notifier).loadHistory();
            await _loadLibrary();
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Dedicated Highlighted Welcome Card
                WelcomeCard(
                  greeting: greeting,
                  languageCode: currentLocale.languageCode,
                  fullName: authState.user?.fullName,
                  onScanPressed: _startScan,
                  onLibraryPressed: () => _showConditionLibraryModal(context),
                ),
                const SizedBox(height: 10),

                // Primary "Scan a Banana" Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1B5E20),
                          Color(0xFF2E7D32),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.primaryGreen.withOpacity(0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: AppConstants.accentYellow,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              currentLocale.languageCode == 'si'
                                  ? 'කඩිනම් කෙසෙල් පරීක්ෂාව'
                                  : (currentLocale.languageCode == 'ta'
                                      ? 'விரைவான வாழைப்பழ ஸ்கேன்'
                                      : 'Quick Banana Scan'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentLocale.languageCode == 'si'
                              ? 'දිලීර රෝග, පොත්තේ භෞතික හානි සහ බරපතලකම Grad-CAM සමඟින් හඳුනා ගැනීමට ඡායාරූපයක් ගන්න හෝ එක් කරන්න.'
                              : (currentLocale.languageCode == 'ta'
                                  ? 'பூஞ்சை நோய்கள், உடல் குறைபாடுகள் மற்றும் தீவிர மதிப்பீட்டை உடனடியாகக் கண்டறிய புகைப்படத்தை எடுக்கவும் அல்லது பதிவேற்றவும்.'
                                  : 'Upload or capture a photo to immediately detect fungal diseases, physical peel defects, and severity rating with Grad-CAM.'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _startScan,
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1B5E20)),
                          label: Text(
                            currentLocale.languageCode == 'si'
                                ? 'දැන් පරීක්ෂා කරන්න'
                                : (currentLocale.languageCode == 'ta'
                                    ? 'இப்போது ஸ்கேன் செய்'
                                    : 'Scan Now'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.accentYellow,
                            foregroundColor: const Color(0xFF1B5E20),
                            elevation: 0,
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // "How to take a good photo" Tips Card
                Builder(builder: (context) {
                  final lang = ref.watch(localeProvider).languageCode;
                  String tipsTitle = 'Photo Tips for Best Accuracy';
                  String tipsBody = '• Hold camera 20-30 cm from fruit\n• Use bright natural light without heavy shadows\n• Avoid severe glare or blurred focus';
                  if (lang == 'si') {
                    tipsTitle = 'නිවැරදි ප්‍රතිඵල සඳහා ඡායාරූප උපදෙස්';
                    tipsBody = '• කැමරාව ගෙඩියේ සිට සෙ.මී. 20-30 දුරින් තබා ගන්න\n• තද සෙවනැලි නොමැති ස්වභාවික ආලෝකය භාවිතා කරන්න\n• ආලෝක පරාවර්තනයෙන් හෝ බොඳවීමෙන් වළකින්න';
                  } else if (lang == 'ta') {
                    tipsTitle = 'துல்லியமான பகுப்பாய்விற்கான புகைப்படக் குறிப்புகள்';
                    tipsBody = '• பழத்திலிருந்து 20-30 செ.மீ தூரத்தில் கேமராவைப் பிடிக்கவும்\n• அதிக நிழல்கள் இல்லாத பிரகாசமான இயற்கை ஒளியைப் பயன்படுத்தவும்\n• கடுமையான வெளிச்சம் அல்லது மங்கலான ஃபோகஸைத் தவிர்க்கவும்';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppConstants.accentYellow,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tipsTitle,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tipsBody,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.4,
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // Condition Library Row (17 Conditions)
                Builder(builder: (context) {
                  final lang = ref.watch(localeProvider).languageCode;
                  String libraryTitle = 'Condition Library (17)';
                  String viewAll = 'View All';
                  if (lang == 'si') {
                    libraryTitle = 'තත්ත්ව සහ රෝග නාමාවලිය (17)';
                    viewAll = 'සියල්ල බලන්න';
                  } else if (lang == 'ta') {
                    libraryTitle = 'நிலை நூலகம் (17)';
                    viewAll = 'அனைத்தும் பார்க்க';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          libraryTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showConditionLibraryModal(context),
                          child: Text(viewAll),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),

                SizedBox(
                  height: 104,
                  child: _isLoadingLibrary
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _libraryConditions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final cond = _libraryConditions[index];
                            final lang = ref.watch(localeProvider).languageCode;
                            final isDisease = cond.type.toLowerCase() == 'disease';
                            final isHealthy = cond.type.toLowerCase() == 'healthy';
                            final chipColor = isHealthy
                                ? AppConstants.primaryGreen
                                : (isDisease ? const Color(0xFFDC2626) : const Color(0xFFD97706));

                            return InkWell(
                              onTap: () => _showConditionDetailModal(context, cond),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 140,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: chipColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cond.getTypeLocalized(lang),
                                        style: TextStyle(
                                          color: chipColor,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cond.nameEn,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      cond.getName(lang),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),

                // Recent Scans
                Consumer(
                  builder: (context, ref, _) {
                    final recentScans = ref.watch(historyProvider).recentScans;
                    final lang = ref.watch(localeProvider).languageCode;
                    String recentTitle = 'Recent Scans';
                    String seeHistory = 'See History';
                    String noScans = 'No scans yet. Start scanning to see results here!';
                    if (lang == 'si') {
                      recentTitle = 'මෑතකදී කළ පරීක්ෂණ';
                      seeHistory = 'ඉතිහාසය බලන්න';
                      noScans = 'තවමත් පරීක්ෂණ සිදු කර නැත. ප්‍රතිඵල බැලීමට පරීක්ෂා කිරීම අරඹන්න!';
                    } else if (lang == 'ta') {
                      recentTitle = 'சமீபத்திய ஸ்கேன்கள்';
                      seeHistory = 'வரலாற்றைக் காண்க';
                      noScans = 'இன்னும் ஸ்கேன்கள் இல்லை. முடிவுகளை இங்கே காண ஸ்கேன் செய்யத் தொடங்குங்கள்!';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                recentTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (recentScans.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    ref.read(historyProvider.notifier).loadHistory();
                                    context.push('/history');
                                  },
                                  child: Text(seeHistory),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (recentScans.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              noScans,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                              ),
                            ),
                          ),
                        )
                      else
                        ...recentScans.map(
                          (scan) => ConditionCard(
                            scan: scan,
                            onTap: () => context.push('/scan-detail?id=${scan.scanId}'),
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConditionLibraryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'All 17 Conditions & Diseases',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _libraryConditions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _libraryConditions[index];
                      final lang = ref.watch(localeProvider).languageCode;
                      final localizedSub = item.getName(lang);
                      final localizedType = item.getTypeLocalized(lang);
                      return ListTile(
                        title: Text(item.nameEn, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('$localizedSub • $localizedType'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showConditionDetailModal(context, item);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showConditionDetailModal(BuildContext context, ConditionInfoModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String selectedSeverity = 'mild';
        final isHealthy = item.type.toLowerCase() == 'healthy';

        return Consumer(
          builder: (context, ref, _) {
            final lang = ref.watch(localeProvider).languageCode;
            final isDisease = item.type.toLowerCase() == 'disease';
            final typeColor = isHealthy
                ? AppConstants.primaryGreen
                : (isDisease ? const Color(0xFFDC2626) : const Color(0xFFD97706));

            return StatefulBuilder(
              builder: (context, setModalState) {
                final causes = isHealthy
                    ? item.getCauseFactorsForSeverity('healthy')
                    : item.getCauseFactorsForSeverity(selectedSeverity);
                final recs = isHealthy
                    ? item.getRecommendationsForSeverity('healthy')
                    : item.getRecommendationsForSeverity(selectedSeverity);

                String sevMildText = 'Mild';
                String sevModText = 'Moderate';
                String sevSevText = 'Severe';
                if (lang == 'si') {
                  sevMildText = 'සුළු';
                  sevModText = 'මධ්‍යස්ථ';
                  sevSevText = 'දැඩි';
                } else if (lang == 'ta') {
                  sevMildText = 'லேசானது';
                  sevModText = 'மிதமானது';
                  sevSevText = 'கடுமையானது';
                }

                final severityTabs = [
                  {'key': 'mild', 'label': sevMildText, 'color': const Color(0xFF16A34A)},
                  {'key': 'moderate', 'label': sevModText, 'color': const Color(0xFFD97706)},
                  {'key': 'severe', 'label': sevSevText, 'color': const Color(0xFFDC2626)},
                ];

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title & Type Badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.getName(lang),
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  if (lang != 'en') ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item.nameEn,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: typeColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                item.getTypeLocalized(lang),
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (item.getDescription(lang).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            item.getDescription(lang),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.75),
                              height: 1.4,
                            ),
                          ),
                        ],

                        // Severity Level Selector (for non-healthy conditions)
                        if (!isHealthy) ...[
                          const SizedBox(height: 18),
                          Text(
                            lang == 'si'
                                ? 'බරපතලකම මට්ටම තෝරන්න:'
                                : (lang == 'ta' ? 'தீவிர நிலையைத் தேர்ந்தெடுக்கவும்:' : 'Select Severity Level:'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: severityTabs.map((tab) {
                              final key = tab['key'] as String;
                              final label = tab['label'] as String;
                              final tabColor = tab['color'] as Color;
                              final isSelected = selectedSeverity == key;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        selectedSeverity = key;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? tabColor : tabColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? tabColor : tabColor.withOpacity(0.35),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : tabColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Cause Factors Section
                        Text(
                          lang == 'si'
                              ? 'ප්‍රධාන හේතු සාධක:'
                              : (lang == 'ta' ? 'முதன்மைக் காரணிகள்:' : 'Cause Factors:'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                        const SizedBox(height: 8),
                        ...causes.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final c = entry.value;
                          final text = c.getLocalized(lang);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$idx. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.primaryGreen,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: const TextStyle(fontSize: 13, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 16),

                        // Recommendations Section
                        Text(
                          lang == 'si'
                              ? 'නිර්දේශිත ක්‍රියාමාර්ග:'
                              : (lang == 'ta' ? 'பரிந்துரைக்கப்பட்ட நடவடிக்கைகள்:' : 'Recommendations:'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                        const SizedBox(height: 8),
                        ...recs.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final r = entry.value;
                          final text = r.getLocalized(lang);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$idx. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.primaryGreen,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: const TextStyle(fontSize: 13, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

