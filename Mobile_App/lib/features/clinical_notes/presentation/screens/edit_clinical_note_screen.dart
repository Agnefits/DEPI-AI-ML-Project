import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/clinical_note.dart';
import '../../data/datasources/clinical_notes_remote_data_source.dart';
import '../../../../injection/injection_container.dart' as di;

class EditClinicalNoteScreen extends StatefulWidget {
  final ClinicalNote note;

  const EditClinicalNoteScreen({super.key, required this.note});

  @override
  State<EditClinicalNoteScreen> createState() => _EditClinicalNoteScreenState();
}

class _EditClinicalNoteScreenState extends State<EditClinicalNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectiveController;
  late TextEditingController _objectiveController;
  late TextEditingController _assessmentController;
  late TextEditingController _planController;
  late TextEditingController _additionalInfoController;
  final ClinicalNotesRemoteDataSource _dataSource = di.sl<ClinicalNotesRemoteDataSource>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _subjectiveController = TextEditingController(text: widget.note.subjective);
    _objectiveController = TextEditingController(text: widget.note.objective);
    _assessmentController = TextEditingController(text: widget.note.assessment);
    _planController = TextEditingController(text: widget.note.plan);
    _additionalInfoController = TextEditingController(text: widget.note.additionalInformation);
  }

  @override
  void dispose() {
    _subjectiveController.dispose();
    _objectiveController.dispose();
    _assessmentController.dispose();
    _planController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _dataSource.updateNote(widget.note.id, {
        'subjective': _subjectiveController.text,
        'objective': _objectiveController.text,
        'assessment': _assessmentController.text,
        'plan': _planController.text,
        'additionalInformation': _additionalInfoController.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1025),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Edit Clinical Note',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Subjective', _subjectiveController, maxLines: 3),
              const SizedBox(height: 16),
              _field('Objective', _objectiveController, maxLines: 3),
              const SizedBox(height: 16),
              _field('Assessment', _assessmentController, maxLines: 3),
              const SizedBox(height: 16),
              _field('Plan', _planController, maxLines: 3),
              const SizedBox(height: 16),
              _field('Additional Information', _additionalInfoController, maxLines: 2),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D6AFB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isSubmitting
                      ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Update Note', style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl, maxLines: maxLines,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            filled: true, fillColor: const Color(0xFF1F2343),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null),
      ],
    );
  }
}
