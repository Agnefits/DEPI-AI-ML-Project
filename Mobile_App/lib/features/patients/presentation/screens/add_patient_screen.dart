import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/patient.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../bloc/patient_bloc.dart';
import '../bloc/patient_event.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({Key? key}) : super(key: key);

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _genderController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _conditionController = TextEditingController();
  final _statusController = TextEditingController(text: 'Stable');
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bloodGroupController.dispose();
    _conditionController.dispose();
    _statusController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newPatient = Patient(
        id: '',
        name: _nameController.text,
        gender: _genderController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        bloodGroup: _bloodGroupController.text,
        condition: _conditionController.text,
        lastVisit: DateTime.now(),
        status: _statusController.text,
        address: _addressController.text,
      );

      context.read<PatientBloc>().add(AddPatientEvent(newPatient));
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
          'Add Patient',
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
            children: [
              CustomTextField(
                label: 'Full Name',
                controller: _nameController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Gender',
                      controller: _genderController,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      label: 'Blood Group',
                      controller: _bloodGroupController,
                    ),
                  ),
                ],
              ),
              CustomTextField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              CustomTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Status',
                      controller: _statusController,
                    ),
                  ),
                ],
              ),
              CustomTextField(
                label: 'Medical Condition',
                controller: _conditionController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Address',
                controller: _addressController,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Save Patient',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
