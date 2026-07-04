import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/case_entity.dart';
import '../bloc/cases_bloc.dart';
import '../bloc/cases_event.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class EditCaseScreen extends StatefulWidget {
  final CaseEntity caseItem;

  const EditCaseScreen({super.key, required this.caseItem});

  @override
  State<EditCaseScreen> createState() => _EditCaseScreenState();
}

class _EditCaseScreenState extends State<EditCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _additionalInfoController;
  late String _status;
  late String _priority;

  final _statuses = ['active', 'closed'];
  final _priorities = ['high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _additionalInfoController = TextEditingController(
      text: widget.caseItem.additionalInformation,
    );
    _status = _statuses.contains(widget.caseItem.status)
        ? widget.caseItem.status
        : _statuses.first;
    _priority = _priorities.contains(widget.caseItem.priority)
        ? widget.caseItem.priority
        : _priorities.first;
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final updated = CaseEntity(
        id: widget.caseItem.id,
        patientName: widget.caseItem.patientName,
        diagnosis: widget.caseItem.diagnosis,
        status: _status,
        priority: _priority,
        patientId: widget.caseItem.patientId,
        additionalInformation: _additionalInfoController.text,
      );

      context.read<CasesBloc>().add(UpdateCaseEvent(updated));
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
          'Edit Case',
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
              _buildDropdown('Status', _status, _statuses, (v) {
                if (v != null) setState(() => _status = v);
              }),
              const SizedBox(height: 20),
              _buildDropdown('Priority', _priority, _priorities, (v) {
                if (v != null) setState(() => _priority = v);
              }),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Additional Information',
                hintText: 'Enter notes or diagnosis',
                controller: _additionalInfoController,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Update Case',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
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
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item[0].toUpperCase() + item.substring(1)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
