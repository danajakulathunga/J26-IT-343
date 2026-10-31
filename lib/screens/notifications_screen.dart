import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/notifications_provider.dart';
import 'package:bananaguard_ai/widgets/bottom_nav_bar.dart';
import 'package:bananaguard_ai/widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'scan_result':
        return Icons.document_scanner_rounded;
      case 'inspection_reminder':
        return Icons.alarm_rounded;
      case 'report':
        return Icons.picture_as_pdf_rounded;
      case 'tip':
      default:
        return Icons.lightbulb_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'scan_result':
        return AppConstants.primaryGreen;
      case 'inspection_reminder':
        return const Color(0xFFD97706);
      case 'report':
        return const Color(0xFF2563EB);
      case 'tip':
      default:
        return AppConstants.accentYellow;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifState = ref.watch(notificationProvider);
    final items = notifState.items;

    final lang = Localizations.localeOf(context).languageCode;
    String title = 'Notifications';
    String markAllRead = 'Mark all as read';
    String settingsTooltip = 'Notification settings';
    String emptyTitle = 'No Notifications';
    String emptyMessage = 'You have read all farm alerts, scan completions and agricultural tips.';

    if (lang == 'si') {
      title = 'දැනුම්දීම්';
      markAllRead = 'සියල්ල කියවූ ලෙස සලකුණු කරන්න';
      settingsTooltip = 'දැනුම්දීම් සැකසුම්';
      emptyTitle = 'දැනුම්දීම් නොමැත';
      emptyMessage = 'ඔබ සියලු අනතුරු ඇඟවීම් සහ උපදෙස් කියවා ඇත.';
    } else if (lang == 'ta') {
      title = 'அறிவிப்புகள்';
      markAllRead = 'அனைத்தையும் படித்ததாகக் குறிக்கவும்';
      settingsTooltip = 'அறிவிப்பு அமைப்புகள்';
      emptyTitle = 'அறிவிப்புகள் எதுவும் இல்லை';
      emptyMessage = 'நீங்கள் அனைத்து எச்சரிக்கைகளையும் படித்துவிட்டீர்கள்.';
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: markAllRead,
            onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: settingsTooltip,
            onPressed: () => context.push('/notification-settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: items.isEmpty
            ? EmptyStateWidget(
                icon: Icons.notifications_none_rounded,
                title: emptyTitle,
                message: emptyMessage,
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final iconColor = _getTypeColor(item.type);

                  return Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppConstants.severitySevere,
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref.read(notificationProvider.notifier).deleteNotification(item.id);
                    },
                    child: ListTile(
                      tileColor: item.isRead ? null : AppConstants.primaryGreen.withOpacity(0.06),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getTypeIcon(item.type), color: iconColor, size: 22),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppConstants.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(item.body, style: const TextStyle(fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, h:mm a').format(item.timestamp),
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!item.isRead) {
                          ref.read(notificationProvider.notifier).markAsRead(item.id);
                        }
                        if (item.type == 'scan_result' && item.payload != null) {
                          context.push('/scan-detail?id=${item.payload}');
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
