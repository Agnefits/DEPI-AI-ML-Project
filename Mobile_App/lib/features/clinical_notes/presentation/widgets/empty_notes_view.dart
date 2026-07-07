import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyNotesView extends StatelessWidget {
  const EmptyNotesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 80,
            color: const Color(0xFF6D6AFB).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No clinical notes found',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add a new note.',
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
