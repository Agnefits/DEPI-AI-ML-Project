import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/profile/presentation/bloc/profile_state.dart';
import '../theme/app_colors.dart';

class GlobalTopBar extends StatelessWidget implements PreferredSizeWidget {
  const GlobalTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: preferredSize.height + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 20,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            bottom: BorderSide(
              color: AppColors.primary.withOpacity(0.15),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── Logo ───────────────────────────────────────────────
            _AppLogo(),

            const Spacer(),

            // ─── Notification bell ──────────────────────────────────
            _NotificationButton(
              onTap: () => context.push('/notifications'),
            ),

            const SizedBox(width: 8),

            // ─── Profile avatar ─────────────────────────────────────
            _ProfileAvatar(
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo
// ─────────────────────────────────────────────────────────────────────────────
class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/Logo.png',
          height: 34,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Clinic',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              TextSpan(
                text: 'AI',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Button
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // TODO: replace with a real unread count from a NotificationsBloc
    const int unreadCount = 0;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Avatar
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileAvatar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          final imageUrl =
              state is ProfileLoaded && state.user.profileImageUrl.isNotEmpty
                  ? state.user.profileImageUrl
                  : null;

          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.card,
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
              child: imageUrl == null
                  ? const Icon(Icons.person, size: 20, color: AppColors.textSecondary)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
