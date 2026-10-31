import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bananaguard_ai/models/notification_item.dart';
import 'package:bananaguard_ai/services/local_db.dart';
import 'package:bananaguard_ai/services/notification_service.dart';

class NotificationState {
  final List<NotificationItem> items;
  final bool isLoading;
  final bool masterEnabled;
  final bool scanResultsEnabled;
  final bool inspectionEnabled;
  final bool tipsEnabled;
  final int reminderHour;
  final int reminderMinute;

  NotificationState({
    this.items = const [],
    this.isLoading = false,
    this.masterEnabled = true,
    this.scanResultsEnabled = true,
    this.inspectionEnabled = true,
    this.tipsEnabled = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
  });

  int get unreadCount => items.where((e) => !e.isRead).length;

  NotificationState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    bool? masterEnabled,
    bool? scanResultsEnabled,
    bool? inspectionEnabled,
    bool? tipsEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return NotificationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      masterEnabled: masterEnabled ?? this.masterEnabled,
      scanResultsEnabled: scanResultsEnabled ?? this.scanResultsEnabled,
      inspectionEnabled: inspectionEnabled ?? this.inspectionEnabled,
      tipsEnabled: tipsEnabled ?? this.tipsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(NotificationState()) {
    loadInbox();
    loadPreferences();
  }

  Future<void> loadInbox() async {
    state = state.copyWith(isLoading: true);
    final list = await localDbService.getNotifications();
    state = state.copyWith(items: list, isLoading: false);
  }

  Future<void> loadPreferences() async {
    final prefs = await notificationService.getPreferences();
    state = state.copyWith(
      masterEnabled: prefs['master'] as bool,
      scanResultsEnabled: prefs['scan_results'] as bool,
      inspectionEnabled: prefs['inspection'] as bool,
      tipsEnabled: prefs['tips'] as bool,
      reminderHour: prefs['hour'] as int,
      reminderMinute: prefs['minute'] as int,
    );
  }

  Future<void> markAsRead(String id) async {
    await localDbService.markAsRead(id);
    final updated = state.items.map((item) {
      if (item.id == id) return item.copyWith(isRead: true);
      return item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  Future<void> markAllAsRead() async {
    await localDbService.markAllAsRead();
    final updated = state.items.map((e) => e.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updated);
  }

  Future<void> deleteNotification(String id) async {
    await localDbService.deleteNotification(id);
    final updated = state.items.where((e) => e.id != id).toList();
    state = state.copyWith(items: updated);
  }

  Future<void> updateSettings({
    required bool master,
    required bool scanResults,
    required bool inspection,
    required bool tips,
    required int hour,
    required int minute,
  }) async {
    await notificationService.savePreferences(
      master: master,
      scanResults: scanResults,
      inspection: inspection,
      tips: tips,
      hour: hour,
      minute: minute,
    );
    state = state.copyWith(
      masterEnabled: master,
      scanResultsEnabled: scanResults,
      inspectionEnabled: inspection,
      tipsEnabled: tips,
      reminderHour: hour,
      reminderMinute: minute,
    );
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});
