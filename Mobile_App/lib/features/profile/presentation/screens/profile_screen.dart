import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/profile_header_widget.dart';
import '../widgets/profile_menu_item_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(LoadProfileEvent());
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      context.read<ProfileBloc>().add(UploadAvatarEvent(file.path));
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final profileBloc = context.read<ProfileBloc>();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: profileBloc,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(
            'Change Password',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Current Password',
                    Icons.lock_outline,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'New Password',
                    Icons.lock_outline,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Confirm New Password',
                    Icons.lock_outline,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            BlocBuilder<ProfileBloc, ProfileState>(
              builder: (ctx, state) {
                final isLoading = state is ProfileLoading;
                return ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (newCtrl.text != confirmCtrl.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match'),
                              ),
                            );
                            return;
                          }
                          profileBloc.add(
                            ChangePasswordEvent(
                              currentPassword: currentCtrl.text,
                              newPassword: newCtrl.text,
                            ),
                          );
                          Navigator.pop(ctx);
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserEntity user) {
    final nameCtrl = TextEditingController(text: user.name);
    final specCtrl = TextEditingController(text: user.specialization);
    final phoneCtrl = TextEditingController(text: user.phoneNumber);

    final profileBloc = context.read<ProfileBloc>();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: profileBloc,
        child: BlocListener<ProfileBloc, ProfileState>(
          listener: (ctx, state) {
            if (state is ProfileUpdateSuccess) {
              Navigator.of(ctx).pop();
              _showResultDialog(
                context,
                success: true,
                message: 'Profile updated successfully!',
              );
            } else if (state is ProfileError) {
              _showResultDialog(
                context,
                success: false,
                message: state.message,
              );
            }
          },
          child: AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            title: Text(
              'Edit Profile',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(
                    controller: nameCtrl,
                    hint: 'Full Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _dialogField(
                    controller: phoneCtrl,
                    hint: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _dialogField(
                    controller: specCtrl,
                    hint: 'Specialization',
                    icon: Icons.work_outline,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              BlocBuilder<ProfileBloc, ProfileState>(
                builder: (ctx, state) {
                  final isLoading = state is ProfileLoading;
                  return ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            final updatedUser = UserEntity(
                              id: user.id,
                              name: nameCtrl.text,
                              email: user.email,
                              phoneNumber: phoneCtrl.text,
                              profileImageUrl: user.profileImageUrl,
                              username: user.username,
                              specialization: specCtrl.text,
                              hospitalName: user.hospitalName,
                              appointmentsCount: user.appointmentsCount,
                              prescriptionsCount: user.prescriptionsCount,
                            );
                            profileBloc.add(UpdateProfileEvent(updatedUser));
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: TextStyle(
        color: readOnly ? AppColors.textSecondary : Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.secondaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        isDense: true,
      ),
    );
  }

  void _showResultDialog(
    BuildContext context, {
    required bool success,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: success ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
            width: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    (success
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE53935))
                        .withOpacity(0.12),
              ),
              child: Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 44,
                color: success
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFE53935),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              success ? 'تمّت العملية بنجاح' : 'حدث خطأ',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: success
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                // ✅ نستخدم dialogCtx عشان نقفل الـ dialog فقط مش الـ route
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  'حسناً',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _helpSection(
                'About the App',
                'clinic AI is a cliniacmanagement application designed to help doctors and healthcare professionals manage their patients, appointments, prescriptions, and clinical notes efficiently.',
              ),
              const SizedBox(height: 20),
              _helpSection(
                'App Permissions',
                '• Internet access for API communication\n• Camera & Gallery for profile picture upload\n• Storage for saving profile images locally',
              ),
              const SizedBox(height: 20),
              _helpSection(
                'Features',
                '• Dashboard with analytics and activity tracking\n• Patient management (add, edit, details)\n• Clinical cases and notes management\n• Appointment scheduling\n• Prescriptions management\n• Profile management with avatar upload\n• Secure authentication & password management',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.secondaryBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _infoRow(
    IconData icon1,
    String label1,
    String value1,
    IconData icon2,
    String label2,
    String value2,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: _infoCell(icon1, label1, value1)),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(child: _infoCell(icon2, label2, value2)),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileAvatarUploadSuccess) {
            _showResultDialog(
              context,
              success: true,
              message: 'Avatar updated successfully!',
            );
          } else if (state is ProfilePasswordChangeSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password changed successfully')),
            );
          } else if (state is ProfileError) {
            // إذا كان الخطأ أثناء رفع صورة نعرض dialog بدل snackbar
            _showResultDialog(context, success: false, message: state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is ProfileLoading || state is ProfileInitial;
          final hasError = state is ProfileError;
          final loaded = state is ProfileLoaded;
          final user = loaded ? state.user : null;

          return Column(
            children: [
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : hasError
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.redAccent, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    state.message,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      context.read<ProfileBloc>().add(LoadProfileEvent());
                                    },
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : loaded
                            ? RefreshIndicator(
                                onRefresh: () async {
                                  context.read<ProfileBloc>().add(LoadProfileEvent());
                                  await context.read<ProfileBloc>().stream.firstWhere(
                                    (s) => s is ProfileLoaded || s is ProfileError,
                                  );
                                },
                                color: AppColors.primary,
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  child: Column(
                                    children: [
                                      ProfileHeaderWidget(
                                        key: ValueKey(user!.profileImageUrl),
                                        user: user,
                                        onAvatarTap: _pickImage,
                                        onEditTap: () =>
                                            _showEditProfileDialog(context, user),
                                      ),
                                      const SizedBox(height: 24),
                                      _infoRow(
                                        Icons.work_outline,
                                        'Specialization',
                                        user.specialization,
                                        Icons.phone_outlined,
                                        'Phone',
                                        user.phoneNumber,
                                      ),
                                      const SizedBox(height: 12),
                                      _infoRow(
                                        Icons.account_circle_outlined,
                                        'Username',
                                        user.username,
                                        Icons.local_hospital_outlined,
                                        'Hospital',
                                        user.hospitalName,
                                      ),
                                      const SizedBox(height: 24),
                                      ProfileMenuItemWidget(
                                        icon: Icons.lock_outline,
                                        title: 'Change Password',
                                        onTap: () =>
                                            _showChangePasswordDialog(context),
                                      ),
                                      ProfileMenuItemWidget(
                                        icon: Icons.edit_outlined,
                                        title: 'Edit Profile',
                                        onTap: () =>
                                            _showEditProfileDialog(context, user),
                                      ),
                                      ProfileMenuItemWidget(
                                        icon: Icons.help_outline,
                                        title: 'Help & Support',
                                        onTap: () => _showHelpDialog(context),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: ProfileMenuItemWidget(
                  icon: Icons.logout,
                  title: 'Logout',
                  isDestructive: true,
                  onTap: () {
                    context.go('/splash');
                    context.read<AuthBloc>().add(LogoutRequested());
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
