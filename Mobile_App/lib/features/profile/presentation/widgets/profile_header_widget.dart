import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_entity.dart';

class ProfileHeaderWidget extends StatelessWidget {
  final UserEntity user;
  final VoidCallback onEditTap;
  final VoidCallback onAvatarTap;

  const ProfileHeaderWidget({
    super.key,
    required this.user,
    required this.onEditTap,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user.profileImageUrl.isNotEmpty
                      ? NetworkImage(user.profileImageUrl)
                      : null,
                  backgroundColor: AppColors.card,
                  child: user.profileImageUrl.isEmpty
                      ? Icon(Icons.person, size: 40, color: AppColors.textSecondary)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
