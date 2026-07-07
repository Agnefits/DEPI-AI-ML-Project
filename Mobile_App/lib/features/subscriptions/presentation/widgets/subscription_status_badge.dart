import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionStatusBadge extends StatelessWidget {
  final String status;

  const SubscriptionStatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isActive = status.toLowerCase() == 'active';
    final Color bgColor = isActive ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFF991B1B).withOpacity(0.3);
    final Color textColor = isActive ? const Color(0xFF60A5FA) : const Color(0xFFF87171);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
