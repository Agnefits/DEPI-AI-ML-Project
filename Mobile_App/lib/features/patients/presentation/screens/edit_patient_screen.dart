import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/patient.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../bloc/patient_bloc.dart';
import '../bloc/patient_event.dart';

class EditPatientScreen extends StatefulWidget {
  final Patient patient;

  const EditPatientScreen({Key? key, required this.patient}) : super(key: key);

  @override
  State<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends State<EditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _genderController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _bloodGroupController;
  late TextEditingController _conditionController;
  late TextEditingController _statusController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient.name);
    _genderController = TextEditingController(text: widget.patient.gender);
    _phoneController = TextEditingController(text: widget.patient.phoneNumber);
    _emailController = TextEditingController(text: widget.patient.email);
    _bloodGroupController = TextEditingController(text: widget.patient.bloodGroup);
    _conditionController = TextEditingController(text: widget.patient.condition);
    _statusController = TextEditingController(text: widget.patient.status);
    _addressController = TextEditingController(text: widget.patient.address);
  }

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
      final updatedPatient = Patient(
        id: widget.patient.id,
        name: _nameController.text,
        gender: _genderController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        bloodGroup: _bloodGroupController.text,
        condition: _conditionController.text,
        lastVisit: widget.patient.lastVisit,
        status: _statusController.text,
        address: _addressController.text,
      );

      context.read<PatientBloc>().add(UpdatePatientEvent(updatedPatient));
      Navigator.pop(context);
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
          'Edit Patient',
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
                text: 'Update Patient',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
