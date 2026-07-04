import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/dashboard_entity.dart';

class ActivityListItem extends StatelessWidget {
  final ActivityEntity activity;

  const ActivityListItem({
    Key? key,
    required this.activity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData getIcon() {
      switch (activity.type) {
        case 'appointment':
          return Icons.calendar_today;
        case 'payment':
          return Icons.payment;
        default:
          return Icons.notifications;
      }
    }

    Color getIconColor() {
      switch (activity.type) {
        case 'appointment':
          return const Color(0xFF6D6AFB);
        case 'payment':
          return Colors.greenAccent;
        default:
          return Colors.orangeAccent;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2343),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: getIconColor().withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(getIcon(), color: getIconColor(), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity.time,
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
