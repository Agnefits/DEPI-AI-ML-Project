import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'stable':
        bgColor = Colors.green.withOpacity(0.2);
        textColor = Colors.greenAccent;
        break;
      case 'critical':
        bgColor = Colors.red.withOpacity(0.2);
        textColor = Colors.redAccent;
        break;
      default:
        bgColor = const Color(0xFF6D6AFB).withOpacity(0.2);
        textColor = const Color(0xFF6D6AFB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
