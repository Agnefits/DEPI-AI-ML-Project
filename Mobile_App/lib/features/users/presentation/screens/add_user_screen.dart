import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../utils/user_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedStatus = 'Active';

  void _submit() {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Name and Email are required', style: GoogleFonts.poppins()),
          backgroundColor: UserColors.error,
        ),
      );
      return;
    }

    final newUser = UserEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      email: _emailController.text,
      role: _roleController.text.isEmpty ? 'Staff' : _roleController.text,
      phone: _phoneController.text.isEmpty ? 'N/A' : _phoneController.text,
      status: _selectedStatus,
    );

    context.read<UsersBloc>().add(AddUser(newUser));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserColors.background,
      appBar: AppBar(
        backgroundColor: UserColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: UserColors.textPrimary),
        title: Text(
          'Add New User',
          style: GoogleFonts.poppins(
            color: UserColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: BlocListener<UsersBloc, UsersState>(
        listener: (context, state) {
          if (state is UserOperationSuccess) {
            Navigator.pop(context);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: GoogleFonts.poppins(
                  color: UserColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Full Name',
                controller: _nameController,
                icon: Icons.person,
              ),
              CustomTextField(
                label: 'Email Address',
                controller: _emailController,
                icon: Icons.email,
              ),
              CustomTextField(
                label: 'Phone Number',
                controller: _phoneController,
                icon: Icons.phone,
              ),
              const SizedBox(height: 16),
              Text(
                'Work Information',
                style: GoogleFonts.poppins(
                  color: UserColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Role / Designation',
                controller: _roleController,
                icon: Icons.badge,
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: UserColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: UserColors.card, width: 2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    dropdownColor: UserColors.card,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: UserColors.primary),
                    items: ['Active', 'Inactive'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: GoogleFonts.poppins(color: UserColors.textPrimary),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        if (newValue != null) _selectedStatus = newValue;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BlocBuilder<UsersBloc, UsersState>(
                builder: (context, state) {
                  return PrimaryButton(
                    text: 'Create User',
                    isLoading: state is UsersLoading,
                    onPressed: _submit,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
