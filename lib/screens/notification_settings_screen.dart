import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/notifications_provider.dart';
import 'package:bananaguard_ai/services/notification_service.dart';

import 'package:bananaguard_ai/providers/locale_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late bool _master;
  late bool _scanResults;
  late bool _inspection;
  late bool _tips;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    final state = ref.read(notificationProvider);
    _master = state.masterEnabled;
    _scanResults = state.scanResultsEnabled;
    _inspection = state.inspectionEnabled;
    _tips = state.tipsEnabled;
    _hour = state.reminderHour;
    _minute = state.reminderMinute;
  }

  Future<void> _save() async {
    final lang = ref.read(localeProvider).languageCode;
    if (_master) {
      await notificationService.requestPermission();
    }

    await ref.read(notificationProvider.notifier).updateSettings(
          master: _master,
          scanResults: _scanResults,
          inspection: _inspection,
          tips: _tips,
          hour: _hour,
          minute: _minute,
        );

    if (mounted) {
      final snackMsg = lang == 'si'
          ? 'දැනුම්දීම් සැකසුම් යාවත්කාලීන විය'
          : (lang == 'ta' ? 'அறிவிப்பு அமைப்புகள் புதுப்பிக்கப்பட்டன' : 'Notification settings updated');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snackMsg)),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
      await _save();
    }
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).languageCode;

    final appBarTitle = lang == 'si'
        ? 'දැනුම්දීම් සැකසුම්'
        : (lang == 'ta' ? 'அறிவிப்பு அமைப்புகள்' : 'Notification Settings');

    final masterTitle = lang == 'si'
        ? 'සියලු දැනුම්දීම් සක්‍රීය කරන්න'
        : (lang == 'ta' ? 'அனைத்து அறிவிப்புகளையும் இயக்கு' : 'Enable All Notifications');
    final masterSub = lang == 'si'
        ? 'පද්ධති දැනුම්දීම් සහ මතක් කිරීම් ලබාගන්න'
        : (lang == 'ta' ? 'கணினி அறிவிப்புகள் மற்றும் நினைவூட்டல்களைப் பெறுக' : 'Receive system alerts and reminders');

    final categoryHeader = lang == 'si'
        ? 'දැනුම්දීම් කාණ්ඩ'
        : (lang == 'ta' ? 'அறிவிப்பு வகைகள்' : 'NOTIFICATION CATEGORIES');

    final scanResultsTitle = lang == 'si'
        ? 'පරීක්ෂණ ප්‍රතිඵල දැනුම්දීම්'
        : (lang == 'ta' ? 'ஸ்கேன் முடிவு விழிப்பூட்டல்கள்' : 'Scan Results & Diagnoses');
    final scanResultsSub = lang == 'si'
        ? 'පරීක්ෂණ විශ්ලේෂණය අවසන් වූ පසු දැනුම්දීම් ලබන්න'
        : (lang == 'ta' ? 'நரம்பியல் ஸ்கேன் முடிந்ததும் அறிவிக்கப்படும்' : 'Get notified when background neural scans finish');

    final inspectionTitle = lang == 'si'
        ? 'වගාබිම් පරීක්ෂණ මතක් කිරීම්'
        : (lang == 'ta' ? 'தோட்ட ஆய்வு நினைவூட்டல்கள்' : 'Orchard Inspection Reminders');
    final inspectionSub = lang == 'si'
        ? 'කෙසෙල් ගස් පරීක්ෂා කිරීම සඳහා දෛනික මතක් කිරීම'
        : (lang == 'ta' ? 'தாவரங்களை ஆய்வு செய்ய தினசரி நினைவூட்டல்' : 'Daily prompt to inspect plants for early disease symptoms');

    final tipsTitle = lang == 'si'
        ? 'කෘෂිකාර්මික උපදෙස් සහ තොරතුරු'
        : (lang == 'ta' ? 'குறிப்புகள் & விவசாய செய்திகள்' : 'Agricultural Tips & Disease Alerts');
    final tipsSub = lang == 'si'
        ? 'කාලගුණ අනතුරු ඇඟවීම් සහ වගා උපදෙස්'
        : (lang == 'ta' ? 'பருவகால எச்சரிக்கைகள் மற்றும் விவசாய வழிகாட்டல்' : 'Seasonal weather warnings and agronomic best practices');

    final reminderTimeHeader = lang == 'si'
        ? 'දෛනික මතක් කිරීමේ වේලාව'
        : (lang == 'ta' ? 'நினைவூட்டல் நேரம்' : 'SCHEDULED REMINDER TIME');

    final dailyReminderTitle = lang == 'si'
        ? 'දෛනික පරීක්ෂණ මතක් කිරීමේ වේලාව'
        : (lang == 'ta' ? 'தினசரி ஆய்வு நினைவூட்டல் நேரம்' : 'Daily Inspection Reminder Time');
    final dailyReminderSub = lang == 'si'
        ? 'මතක් කිරීම් ලැබෙන වේලාව තෝරන්න'
        : (lang == 'ta' ? 'நினைவூட்டல் பெற நேரத்தைத் தேர்ந்தெடுக்கவும்' : 'Tap to change reminder time');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Master Switch
            Card(
              child: SwitchListTile(
                value: _master,
                activeColor: AppConstants.primaryGreen,
                title: Text(masterTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(masterSub),
                onChanged: (val) {
                  setState(() => _master = val);
                  _save();
                },
              ),
            ),
            const SizedBox(height: 16),

            // Categories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                categoryHeader,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),

            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _master && _scanResults,
                    activeColor: AppConstants.primaryGreen,
                    title: Text(scanResultsTitle),
                    subtitle: Text(scanResultsSub),
                    onChanged: _master
                        ? (val) {
                            setState(() => _scanResults = val);
                            _save();
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _master && _inspection,
                    activeColor: AppConstants.primaryGreen,
                    title: Text(inspectionTitle),
                    subtitle: Text(inspectionSub),
                    onChanged: _master
                        ? (val) {
                            setState(() => _inspection = val);
                            _save();
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _master && _tips,
                    activeColor: AppConstants.primaryGreen,
                    title: Text(tipsTitle),
                    subtitle: Text(tipsSub),
                    onChanged: _master
                        ? (val) {
                            setState(() => _tips = val);
                            _save();
                          }
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily Reminder Time Picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                reminderTimeHeader,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time_rounded, color: AppConstants.primaryGreen),
                title: Text(dailyReminderTitle),
                subtitle: Text(dailyReminderSub),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatTime(_hour, _minute),
                    style: const TextStyle(
                      color: AppConstants.primaryGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                onTap: _master && _inspection ? _pickTime : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
