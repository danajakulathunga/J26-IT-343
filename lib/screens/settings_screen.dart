import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';
import 'package:bananaguard_ai/providers/theme_provider.dart';
import 'package:bananaguard_ai/core/api_client.dart';
import 'package:bananaguard_ai/widgets/server_config_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final lang = ref.read(localeProvider).languageCode;
    final dialogTitle = lang == 'si'
        ? 'භාෂාව තෝරන්න'
        : (lang == 'ta' ? 'மொழியைத் தேர்ந்தெடுக்கவும்' : 'Select Language');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'en',
              groupValue: lang,
              title: const Text('English'),
              activeColor: AppConstants.primaryGreen,
              onChanged: (val) {
                if (val != null) {
                  ref.read(localeProvider.notifier).setLocale(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<String>(
              value: 'si',
              groupValue: lang,
              title: const Text('සිංහල'),
              activeColor: AppConstants.primaryGreen,
              onChanged: (val) {
                if (val != null) {
                  ref.read(localeProvider.notifier).setLocale(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<String>(
              value: 'ta',
              groupValue: lang,
              title: const Text('தமிழ்'),
              activeColor: AppConstants.primaryGreen,
              onChanged: (val) {
                if (val != null) {
                  ref.read(localeProvider.notifier).setLocale(val);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.read(themeProvider);
    final lang = ref.read(localeProvider).languageCode;

    final dialogTitle = lang == 'si'
        ? 'යෙදුම් තේමාව'
        : (lang == 'ta' ? 'பயன்பாட்டு தீம்' : 'App Theme');
    final systemTitle = lang == 'si'
        ? 'පද්ධති පෙරනිමිය'
        : (lang == 'ta' ? 'கணினி இயல்புநிலை' : 'System Default');
    final lightTitle = lang == 'si'
        ? 'ආලෝකමත් මාදිලිය'
        : (lang == 'ta' ? 'ஒளி பயன்முறை' : 'Light Mode');
    final darkTitle = lang == 'si'
        ? 'අඳුරු මාදිලිය'
        : (lang == 'ta' ? 'இருண்ட பயன்முறை' : 'Dark Mode');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: currentTheme,
              title: Text(systemTitle),
              activeColor: AppConstants.primaryGreen,
              onChanged: (val) {
                if (val != null) {
                  ref.read(themeProvider.notifier).setThemeMode(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: currentTheme,
              title: Text(lightTitle),
              activeColor: AppConstants.primaryGreen,
              onChanged: (val) {
                if (val != null) {
                  ref.read(themeProvider.notifier).setThemeMode(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: currentTheme,
              title: Text(darkTitle),
              activeColor: AppConstants.primaryGreen,
              onChanged: (val) {
                if (val != null) {
                  ref.read(themeProvider.notifier).setThemeMode(val);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAboutDialog(BuildContext context, String lang) async {
    String mode = 'demo';
    String version = '1.0.0';
    try {
      final res = await apiClient.dio.get('/health');
      mode = res.data['mode'] as String? ?? 'demo';
      version = res.data['version'] as String? ?? '1.0.0';
    } catch (_) {}

    final aboutTitle = lang == 'si'
        ? 'BananaGuard AI පිළිබඳව'
        : (lang == 'ta' ? 'BananaGuard AI பற்றி' : 'About BananaGuard AI');
    final versionLabel = lang == 'si' ? 'අනුවාදය: $version' : (lang == 'ta' ? 'பதிப்பு: $version' : 'Version: $version');
    final modeLabel = lang == 'si' ? 'ක්‍රියාකාරී මාදිලිය: ' : (lang == 'ta' ? 'செயல்பாட்டு முறை: ' : 'Operational Mode: ');
    final aboutDesc = lang == 'si'
        ? 'ශ්‍රී ලංකාවේ කෙසෙල් ප්‍රභේද සඳහා ස්වයංක්‍රීය දෝෂ හා රෝග වර්ගීකරණය, බරපතලකම තක්සේරු කිරීම සහ Grad-CAM පැහැදිලි කිරීම.'
        : (lang == 'ta'
            ? 'இலங்கை வாழை வகைகளுக்கான தானியங்கி குறைபாடு மற்றும் நோய் வகைப்படுத்தல், தீவிர மதிப்பீடு மற்றும் Grad-CAM விளக்கம்.'
            : 'Automated defect and disease classification, severity estimation, and Grad-CAM explainability for Sri Lankan banana cultivars.');
    final closeBtn = lang == 'si' ? 'වසන්න' : (lang == 'ta' ? 'மூடு' : 'Close');

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppConstants.primaryGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(aboutTitle)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(versionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(modeLabel),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: mode == 'demo' ? Colors.amber[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mode.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: mode == 'demo' ? Colors.amber[900] : Colors.green[900],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                aboutDesc,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(closeBtn)),
          ],
        ),
      );
    }
  }

  void _showPrivacyDialog(BuildContext context, String lang) {
    final title = lang == 'si'
        ? 'පෞද්ගලිකත්වය සහ පර්යේෂණ හෙළිදරව්ව'
        : (lang == 'ta' ? 'தனியுரிமை மற்றும் ஆராய்ச்சி வெளிப்படுத்தல்' : 'Privacy & Research Disclosure');
    final desc = lang == 'si'
        ? 'BananaGuard AI යනු ශාස්ත්‍රීය පර්යේෂණ රෝග විනිශ්චය මෙවලමකි. උඩුගත කරන ලද කෙසෙල් ඡායාරූප දෝෂ/රෝග හඳුනාගැනීම, බරපතලකම් දර්ශකය ගණනය කිරීම සහ Grad-CAM දෘශ්‍යකරණය සඳහා සකසනු ලැබේ.\n\nසියලුම රෝග විනිශ්චය මගපෙන්වීම් තීරණ-සහාය තොරතුරු ලෙස පමණක් සපයනු ලබන අතර සහතික කළ කෘෂිකාර්මික ප්‍රතිකාර ප්‍රකාශයක් නොවේ. ප්‍රතිකාර යෙදීමට පෙර ප්‍රාදේශීය කෘෂිකර්ම නිලධාරීන්ගෙන් උපදෙස් ලබා ගන්නා ලෙස වගාකරුවන්ට උපදෙස් දෙනු ලැබේ.'
        : (lang == 'ta'
            ? 'BananaGuard AI என்பது ஒரு கல்வி ஆராய்ச்சி கண்டறியும் கருவியாகும். பதிவேற்றப்பட்ட வாழைப்பழ படங்கள் குறைபாடு/நோய் கண்டறிதல், தீவிர குறியீட்டு கணக்கீடு மற்றும் காட்சிப்படுத்தலுக்காக செயலாக்கப்படுகின்றன.\n\nஅனைத்து நோயறிதல் வழிகாட்டுதல்களும் முடிவு ஆதரவு தகவலாக மட்டுமே வழங்கப்படுகின்றன. சிகிச்சைகளைப் பயன்படுத்துவதற்கு முன் உள்ளூர் விவசாய அதிகாரிகளை அணுகுமாறு விவசாயிகள் அறிவுறுத்தப்படுகிறார்கள்.'
            : 'BananaGuard AI is an academic research diagnostic tool. Uploaded banana images are processed for defect/disease detection, severity index calculation, and attention visualization.\n\nAll diagnostic guidance is provided strictly as decision-support information and does not constitute a certified agricultural treatment claim. Growers are advised to consult local agricultural extension officers before applying treatments.');
    final ackBtn = lang == 'si' ? 'තේරුම් ගතිමි' : (lang == 'ta' ? 'ஒப்புக்கொள்கிறேன்' : 'Acknowledge');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            desc,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ackBtn)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final lang = locale.languageCode;

    String langName = 'English';
    if (lang == 'si') langName = 'සිංහල';
    if (lang == 'ta') langName = 'தமிழ்';

    String themeName = lang == 'si' ? 'පද්ධති පෙරනිමිය' : (lang == 'ta' ? 'கணினி இயல்புநிலை' : 'System Default');
    if (themeMode == ThemeMode.light) {
      themeName = lang == 'si' ? 'ආලෝකමත් මාදිලිය' : (lang == 'ta' ? 'ஒளி பயன்முறை' : 'Light Mode');
    }
    if (themeMode == ThemeMode.dark) {
      themeName = lang == 'si' ? 'අඳුරු මාදිලිය' : (lang == 'ta' ? 'இருண்ட பயன்முறை' : 'Dark Mode');
    }

    final appBarTitle = lang == 'si' ? 'සැකසුම්' : (lang == 'ta' ? 'அமைப்புகள்' : 'Settings');
    final langTileTitle = lang == 'si' ? 'භාෂාව' : (lang == 'ta' ? 'மொழி' : 'Language');
    final themeTileTitle = lang == 'si' ? 'තේමා මාදිලිය' : (lang == 'ta' ? 'தீம் முறை' : 'Theme Mode');
    final notifTileTitle = lang == 'si' ? 'දැනුම්දීම් සැකසුම්' : (lang == 'ta' ? 'அறிவிப்பு விருப்பங்கள்' : 'Notification Preferences');
    final notifTileSub = lang == 'si' ? 'මතක් කිරීම් සහ අනතුරු ඇඟවීම්' : (lang == 'ta' ? 'நினைவூட்டல்கள் மற்றும் எச்சரிக்கைகள்' : 'Inspection reminders & alerts');
    final serverTileTitle = lang == 'si'
        ? 'සේවාදායක සම්බන්ධතාවය (API Server)'
        : (lang == 'ta' ? 'சர்வர் இணைப்பு (API Server)' : 'Server Connection (API Server)');
    final serverTileSub = lang == 'si'
        ? 'Cloudflare Tunnel හෝ දේශීය IP ලිපිනය වෙනස් කරන්න'
        : (lang == 'ta' ? 'Cloudflare Tunnel அல்லது உள்ளூர் IP' : 'Cloudflare Tunnel or Local IP configuration');

    final aboutTileTitle = lang == 'si' ? 'BananaGuard AI පිළිබඳව' : (lang == 'ta' ? 'BananaGuard AI பற்றி' : 'About BananaGuard AI');
    final aboutTileSub = lang == 'si' ? 'අනුවාදය, ක්‍රියාකාරී මාදිලිය සහ තොරතුරු' : (lang == 'ta' ? 'பதிப்பு, கணினி முறை மற்றும் ஆராய்ச்சி தகவல்' : 'Version, system mode & research info');
    final privacyTileTitle = lang == 'si' ? 'පෞද්ගලිකත්වය සහ වියාචන සටහන' : (lang == 'ta' ? 'தனியுரிமை மற்றும் மறுப்பு குறிப்பு' : 'Privacy & Disclaimer Note');
    final privacyTileSub = lang == 'si' ? 'තීරණ සහායක භාවිත කොන්දේසි' : (lang == 'ta' ? 'முடிவு ஆதரவு பயன்பாட்டு விதிமுறைகள்' : 'Decision-support terms of use');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: AppConstants.primaryGreen),
                    title: Text(langTileTitle),
                    subtitle: Text(langName),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showLanguageDialog(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.brightness_6_rounded, color: AppConstants.primaryGreen),
                    title: Text(themeTileTitle),
                    subtitle: Text(themeName),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showThemeDialog(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined, color: AppConstants.primaryGreen),
                    title: Text(notifTileTitle),
                    subtitle: Text(notifTileSub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/notification-settings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.dns_rounded, color: AppConstants.primaryGreen),
                    title: Text(serverTileTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apiClient.dio.options.baseUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          serverTileSub,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showServerConfigDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppConstants.primaryGreen),
                    title: Text(aboutTileTitle),
                    subtitle: Text(aboutTileSub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showAboutDialog(context, lang),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppConstants.primaryGreen),
                    title: Text(privacyTileTitle),
                    subtitle: Text(privacyTileSub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showPrivacyDialog(context, lang),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
