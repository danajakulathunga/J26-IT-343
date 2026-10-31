import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/auth_provider.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _editNameDialog(BuildContext context, WidgetRef ref, String currentName, String lang) {
    final controller = TextEditingController(text: currentName);
    final dialogTitle = lang == 'si'
        ? 'නම වෙනස් කරන්න'
        : (lang == 'ta' ? 'பெயரைத் திருத்து' : 'Edit Name');
    final labelText = lang == 'si'
        ? 'සම්පූර්ණ නම'
        : (lang == 'ta' ? 'முழு பெயர்' : 'Full Name');
    final cancelText = lang == 'si'
        ? 'අවලංගු කරන්න'
        : (lang == 'ta' ? 'ரத்து செய்' : 'Cancel');
    final saveText = lang == 'si'
        ? 'සුරකින්න'
        : (lang == 'ta' ? 'சேமிக்கவும்' : 'Save');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: labelText),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancelText)),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final auth = ref.read(authProvider);
                if (auth.isGuest) {
                  await ref.read(authProvider.notifier).loginAsGuest(newName);
                } else {
                  await ref.read(authProvider.notifier).updateProfile(fullName: newName);
                }
              }
              if (context.mounted) Navigator.pop(ctx);
            },
            child: Text(saveText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final lang = ref.watch(localeProvider).languageCode;

    final isGuest = authState.isGuest || user == null;
    final guestFallback = lang == 'si' ? 'අමුත්තා' : (lang == 'ta' ? 'விருந்தினர் பயனர்' : 'Guest User');
    final guestSession = lang == 'si' ? 'අමුත්තන්ගේ සැසිය' : (lang == 'ta' ? 'விருந்தினர் அமர்வு' : 'Guest Session');
    final displayName = user?.fullName.isNotEmpty == true ? user!.fullName : guestFallback;
    final displayEmail = isGuest ? guestSession : user?.email ?? '';

    final appBarTitle = lang == 'si' ? 'ගිණුම' : (lang == 'ta' ? 'சுயவிவரம்' : 'Profile');
    final syncTitle = lang == 'si'
        ? 'ඔබගේ පරීක්ෂණ දත්ත සියලු උපාංග අතර සමමුහුර්ත කරන්න'
        : (lang == 'ta'
            ? 'சாதனங்கள் முழுவதும் ஸ்கேன்களை ஒத்திசைக்கவும்'
            : 'Sync Your Scans Across Devices');
    final syncDesc = lang == 'si'
        ? 'ඔබ අමුත්තන්ගේ මාදිලිය භාවිතා කරයි. ඔබගේ වාර්තා ස්ථිරව සුරැකීමට නොමිලේ ගිණුමක් සාදන්න.'
        : (lang == 'ta'
            ? 'விருந்தினர் பயன்முறையைப் பயன்படுத்துகிறீர்கள். மேகக்கணியில் நிரந்தரமாகச் சேமிக்க இலவச கணக்கை உருவாக்கவும்.'
            : 'You are using Guest Mode. Create a free account to permanently save your scan diagnostics to the cloud.');
    final createAccountBtn = lang == 'si'
        ? 'නොමිලේ ගිණුමක් සාදන්න'
        : (lang == 'ta' ? 'இலவச கணக்கை உருவாக்கவும்' : 'Create Free Account');

    final appSettingsTitle = lang == 'si'
        ? 'යෙදුම් සැකසුම්'
        : (lang == 'ta' ? 'பயன்பாட்டு அமைப்புகள்' : 'App Settings');
    final appSettingsSub = lang == 'si'
        ? 'භාෂාව, තේමාව සහ තොරතුරු'
        : (lang == 'ta' ? 'மொழி, தீம் மற்றும் பற்றி' : 'Language, theme & about');

    final notifTitle = lang == 'si'
        ? 'දැනුම්දීම් සැකසුම්'
        : (lang == 'ta' ? 'அறிவிப்பு விருப்பங்கள்' : 'Notification Preferences');
    final notifSub = lang == 'si'
        ? 'මතක් කිරීම් සහ අනතුරු ඇඟවීම්'
        : (lang == 'ta' ? 'நினைவூட்டல்கள் மற்றும் எச்சரிக்கைகள்' : 'Reminders, alert sounds & categories');

    final historyTitle = lang == 'si'
        ? 'පරීක්ෂණ ඉතිහාසය'
        : (lang == 'ta' ? 'கண்டறிதல் வரலாறு' : 'Diagnostic History');
    final historySub = lang == 'si'
        ? 'පසුගිය වාර්තා පරීක්ෂා කරන්න'
        : (lang == 'ta' ? 'கடந்த கால அறிக்கைகளை மதிப்பாய்வு செய்' : 'Review past banana reports');

    final logoutDialogTitle = isGuest
        ? (lang == 'si' ? 'අමුත්තන්ගේ මාදිලියෙන් පිටවීම' : (lang == 'ta' ? 'விருந்தினர் பயன்முறையிலிருந்து வெளியேறு' : 'Exit Guest Mode'))
        : (lang == 'si' ? 'පිටවන්න' : (lang == 'ta' ? 'வெளியேறவும்' : 'Sign Out'));
    final logoutDialogContent = isGuest
        ? (lang == 'si' ? 'ඔබට අමුත්තන්ගේ සැසියෙන් ඉවත් වීමට අවශ්‍ය බව සහතිකද?' : (lang == 'ta' ? 'விருந்தினர் அமர்விலிருந்து வெளியேற விரும்புகிறீர்களா?' : 'Are you sure you want to exit your guest session?'))
        : (lang == 'si' ? 'ඔබට BananaGuard AI වෙතින් පිටවීමට අවශ්‍ය බව සහතිකද?' : (lang == 'ta' ? 'BananaGuard AI இலிருந்து வெளியேற விரும்புகிறீர்களா?' : 'Are you sure you want to sign out of BananaGuard AI?'));
    final cancelBtn = lang == 'si' ? 'අවලංගු කරන්න' : (lang == 'ta' ? 'ரத்து செய்' : 'Cancel');
    final logoutBtnText = isGuest
        ? (lang == 'si' ? 'අමුත්තන්ගේ සැසියෙන් පිටවන්න' : (lang == 'ta' ? 'விருந்தினர் அமர்விலிருந்து வெளியேறு' : 'Exit Guest Session'))
        : (lang == 'si' ? 'පිටවන්න' : (lang == 'ta' ? 'வெளியேறவும்' : 'Sign Out'));

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // User Avatar Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppConstants.primaryGreen.withOpacity(0.15),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _editNameDialog(context, ref, displayName, lang),
                            ),
                          ],
                        ),
                        Text(
                          displayEmail,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Gentle "Create account to sync history" prompt for guests
            if (isGuest) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync_outlined, color: Color(0xFFB45309), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            syncTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      syncDesc,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.push('/sign-up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryGreen,
                        minimumSize: const Size(double.infinity, 42),
                      ),
                      child: Text(createAccountBtn),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action List
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppConstants.primaryGreen),
                    title: Text(appSettingsTitle),
                    subtitle: Text(appSettingsSub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined, color: AppConstants.primaryGreen),
                    title: Text(notifTitle),
                    subtitle: Text(notifSub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/notification-settings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history_rounded, color: AppConstants.primaryGreen),
                    title: Text(historyTitle),
                    subtitle: Text(historySub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/history'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout / Exit Guest Session
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(logoutDialogTitle),
                    content: Text(logoutDialogContent),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelBtn)),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(logoutBtnText)),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/sign-in');
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: Text(
                logoutBtnText,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
