import 'package:flutter/material.dart';

class NotificationTypeIcon extends StatelessWidget {
  final String type;
  final bool isRead;

  const NotificationTypeIcon({
    super.key,
    required this.type,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'appointment':
        iconData = Icons.calendar_today_rounded;
        iconColor = const Color(0xFF6D6AFB); // Primary
        break;
      case 'message':
        iconData = Icons.message_rounded;
        iconColor = const Color(0xFF00C48C); // Green
        break;
      case 'alert':
      default:
        iconData = Icons.notifications_active_rounded;
        iconColor = const Color(0xFFFF647C); // Red/Pink
        break;
    }

    bgColor = iconColor.withOpacity(0.15);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRead ? Colors.grey.withOpacity(0.1) : bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: isRead ? Colors.grey : iconColor,
        size: 24,
      ),
    );
  }
}
