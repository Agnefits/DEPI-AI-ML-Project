import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyCasesView extends StatelessWidget {
  final String message;

  const EmptyCasesView({
    Key? key,
    this.message = 'No cases found. Create a new one!',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
