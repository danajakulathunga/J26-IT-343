class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // scan_result, inspection_reminder, tip, report
  final DateTime timestamp;
  final bool isRead;
  final String? payload;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.payload,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    String? payload,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'payload': payload,
    };
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: map['type'] as String? ?? 'tip',
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: (map['is_read'] as int? ?? 0) == 1,
      payload: map['payload'] as String?,
    );
  }
}
