import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/datasources/clinical_notes_remote_data_source.dart';
import '../../../../injection/injection_container.dart' as di;
import '../../../cases/data/datasources/cases_remote_data_source.dart';
import '../../../cases/data/models/case_model.dart';

class AddClinicalNoteScreen extends StatefulWidget {
  const AddClinicalNoteScreen({super.key});

  @override
  State<AddClinicalNoteScreen> createState() => _AddClinicalNoteScreenState();
}

class _AddClinicalNoteScreenState extends State<AddClinicalNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectiveController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _assessmentController = TextEditingController();
  final _planController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  final ClinicalNotesRemoteDataSource _dataSource = di.sl<ClinicalNotesRemoteDataSource>();
  final CasesRemoteDataSource _casesDataSource = di.sl<CasesRemoteDataSource>();

  List<CaseModel> _cases = [];
  CaseModel? _selectedCase;
  bool _isLoadingCases = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    try {
      final cases = await _casesDataSource.getCases();
      if (mounted) {
        setState(() {
          _cases = cases;
          _isLoadingCases = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCases = false);
      }
    }
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
    if (!_formKey.currentState!.validate() || _selectedCase == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _dataSource.addCaseNote(_selectedCase!.id, {
        'subjective': _subjectiveController.text,
        'objective': _objectiveController.text,
        'assessment': _assessmentController.text,
        'plan': _planController.text,
        'additionalInformation': _additionalInfoController.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully')),
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
          'Add Clinical Note',
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
              Text('Case',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _isLoadingCases
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: Color(0xFF6D6AFB), strokeWidth: 2)))
                  : DropdownButtonFormField<CaseModel>(
                      value: _selectedCase,
                      dropdownColor: const Color(0xFF1F2343),
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true, fillColor: const Color(0xFF1F2343),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      style: GoogleFonts.poppins(color: Colors.white),
                      hint: Text('Select a case', style: GoogleFonts.poppins(color: Colors.white38)),
                      items: _cases.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.patientName.isNotEmpty ? '${c.patientName} (#${c.id})' : 'Case #${c.id}',
                            overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedCase = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
              const SizedBox(height: 20),
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
                      : Text('Save Note', style: GoogleFonts.poppins(
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
