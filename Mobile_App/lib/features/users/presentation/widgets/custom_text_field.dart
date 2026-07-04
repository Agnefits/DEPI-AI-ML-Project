import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/user_colors.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isPassword;

  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.poppins(color: UserColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: UserColors.textSecondary),
          prefixIcon: Icon(icon, color: UserColors.primary),
          filled: true,
          fillColor: UserColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: UserColors.card, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: UserColors.card, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: UserColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
