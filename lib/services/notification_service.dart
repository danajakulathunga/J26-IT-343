import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bananaguard_ai/models/notification_item.dart';
import 'package:bananaguard_ai/services/local_db.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String keyMasterEnabled = 'notif_master_enabled';
  static const String keyScanResults = 'notif_scan_results';
  static const String keyInspectionReminders = 'notif_inspection_reminders';
  static const String keyTips = 'notif_tips';
  static const String keyReminderHour = 'notif_reminder_hour';
  static const String keyReminderMinute = 'notif_reminder_minute';

  Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(initSettings);
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return true;
  }

  // --- Notification Preferences ---
  Future<Map<String, dynamic>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'master': prefs.getBool(keyMasterEnabled) ?? true,
      'scan_results': prefs.getBool(keyScanResults) ?? true,
      'inspection': prefs.getBool(keyInspectionReminders) ?? true,
      'tips': prefs.getBool(keyTips) ?? true,
      'hour': prefs.getInt(keyReminderHour) ?? 9,
      'minute': prefs.getInt(keyReminderMinute) ?? 0,
    };
  }

  Future<void> savePreferences({
    required bool master,
    required bool scanResults,
    required bool inspection,
    required bool tips,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMasterEnabled, master);
    await prefs.setBool(keyScanResults, scanResults);
    await prefs.setBool(keyInspectionReminders, inspection);
    await prefs.setBool(keyTips, tips);
    await prefs.setInt(keyReminderHour, hour);
    await prefs.setInt(keyReminderMinute, minute);

    if (master && inspection) {
      await scheduleDailyReminder(hour, minute);
    } else {
      await cancelDailyReminder();
    }
  }

  // --- Schedule Reminder ---
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    if (kIsWeb) return;
    await _plugin.cancel(101); // Cancel existing reminder ID

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'inspection_reminders',
      'Orchard Inspection Reminders',
      channelDescription: 'Daily reminders to inspect banana crops for defects and diseases',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      101,
      'Banana Orchard Inspection Reminder',
      'Take a quick scan today to ensure your banana plantation remains free of disease.',
      scheduledTime,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(101);
  }

  // --- Post In-App & System Notification ---
  Future<void> postNotification({
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    final prefs = await getPreferences();
    if (!prefs['master']) return;

    if (type == 'scan_result' && !prefs['scan_results']) return;
    if (type == 'inspection_reminder' && !prefs['inspection']) return;
    if (type == 'tip' && !prefs['tips']) return;

    // 1. Save to SQLite / Web In-App Inbox
    final item = NotificationItem(
      id: const Uuid().v4(),
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      payload: payload,
    );
    await localDbService.insertNotification(item);

    // 2. Show native status bar notification if on mobile
    if (!kIsWeb) {
      const androidDetails = AndroidNotificationDetails(
        'general_notifications',
        'BananaGuard Notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      await _plugin.show(
        DateTime.now().millisecond,
        title,
        body,
        const NotificationDetails(android: androidDetails),
        payload: payload,
      );
    }
  }
}

final notificationService = NotificationService();
