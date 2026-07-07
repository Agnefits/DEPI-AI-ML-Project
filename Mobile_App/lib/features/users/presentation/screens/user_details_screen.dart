import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/user_entity.dart';
import '../utils/user_colors.dart';
import '../widgets/info_row.dart';
import '../widgets/user_avatar.dart';
import '../widgets/primary_button.dart';
import '../bloc/users_bloc.dart';
import 'edit_user_screen.dart';

class UserDetailsScreen extends StatelessWidget {
  final UserEntity user;

  const UserDetailsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserColors.background,
      appBar: AppBar(
        backgroundColor: UserColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: UserColors.textPrimary),
        title: Text(
          'User Details',
          style: GoogleFonts.poppins(
            color: UserColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: UserColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<UsersBloc>(),
                    child: EditUserScreen(user: user),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Hero(
                tag: 'avatar_${user.id}',
                child: UserAvatar(name: user.name, radius: 50),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: GoogleFonts.poppins(
                color: UserColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: user.status.toLowerCase() == 'active'
                    ? UserColors.success.withOpacity(0.1)
                    : UserColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.status.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: user.status.toLowerCase() == 'active'
                      ? UserColors.success
                      : UserColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: UserColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.badge,
                    label: 'Role / Designation',
                    value: user.role,
                  ),
                  const Divider(color: UserColors.background, height: 24, thickness: 1.5),
                  InfoRow(
                    icon: Icons.email,
                    label: 'Email Address',
                    value: user.email,
                  ),
                  const Divider(color: UserColors.background, height: 24, thickness: 1.5),
                  InfoRow(
                    icon: Icons.phone,
                    label: 'Phone Number',
                    value: user.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            PrimaryButton(
              text: 'Message User',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Messaging not implemented yet', style: GoogleFonts.poppins()),
                    backgroundColor: UserColors.primary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
