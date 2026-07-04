import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/user_colors.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    String initials = name.isNotEmpty 
        ? name.trim().split(RegExp(' +')).map((s) => s[0]).take(2).join().toUpperCase() 
        : '?';
        
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? UserColors.primary.withOpacity(0.2),
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          color: UserColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
