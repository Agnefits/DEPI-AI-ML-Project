import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/case_entity.dart';
import '../bloc/cases_bloc.dart';
import '../bloc/cases_event.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../../../patients/data/datasources/patients_remote_data_source.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../../../injection/injection_container.dart' as di;

class AddCaseScreen extends StatefulWidget {
  final String? patientId;

  const AddCaseScreen({super.key, this.patientId});

  @override
  State<AddCaseScreen> createState() => _AddCaseScreenState();
}

class _AddCaseScreenState extends State<AddCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _additionalInfoController = TextEditingController();
  final PatientsRemoteDataSource _patientsDataSource = di.sl<PatientsRemoteDataSource>();
  String _priority = 'medium';

  final _priorities = ['high', 'medium', 'low'];

  List<PatientModel> _patients = [];
  PatientModel? _selectedPatient;
  bool _isLoadingPatients = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await _patientsDataSource.getPatients();
      if (mounted) {
        setState(() {
          _patients = patients;
          _isLoadingPatients = false;
          if (widget.patientId != null) {
            _selectedPatient = patients.cast<PatientModel?>().firstWhere(
              (p) => p?.id == widget.patientId,
              orElse: () => null,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPatients = false);
      }
    }
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newCase = CaseEntity(
        id: '',
        patientName: '',
        status: 'active',
        priority: _priority,
        patientId: int.tryParse(_selectedPatient?.id ?? '') ?? 0,
        additionalInformation: _additionalInfoController.text,
      );

      context.read<CasesBloc>().add(CreateCaseEvent(newCase));
      Navigator.pop(context);
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
          'Add Case',
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
              Text('Patient',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _isLoadingPatients
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: Color(0xFF6D6AFB), strokeWidth: 2)))
                  : DropdownButtonFormField<PatientModel>(
                      value: _selectedPatient,
                      dropdownColor: const Color(0xFF1F2343),
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1F2343),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: GoogleFonts.poppins(color: Colors.white),
                      hint: Text('Select a patient', style: GoogleFonts.poppins(color: Colors.white38)),
                      items: _patients.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: widget.patientId != null ? null : (v) => setState(() => _selectedPatient = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
              const SizedBox(height: 20),
              Text(
                'Priority',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _priority,
                dropdownColor: const Color(0xFF1F2343),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1F2343),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.poppins(color: Colors.white),
                items: _priorities.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(p[0].toUpperCase() + p.substring(1)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _priority = v);
                },
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Additional Information',
                hintText: 'Enter notes or diagnosis',
                controller: _additionalInfoController,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Save Case',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
