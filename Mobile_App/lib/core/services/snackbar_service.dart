import 'package:flutter/material.dart';
import '../routing/app_router.dart';
import '../theme/app_colors.dart';

enum SnackBarType { success, error, warning, info }

class SnackBarService {
  static void showSuccess(String message) {
    show(message: message, type: SnackBarType.success);
  }

  static void showError(String message) {
    show(message: message, type: SnackBarType.error);
  }

  static void showWarning(String message) {
    show(message: message, type: SnackBarType.warning);
  }

  static void showInfo(String message) {
    show(message: message, type: SnackBarType.info);
  }

  static void show({
    required String message,
    required SnackBarType type,
    Duration duration = const Duration(seconds: 4),
  }) {
    final context = AppRouter.navigatorKey.currentState?.overlay?.context;
    if (context == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Clear current snackbars to avoid queuing
    scaffoldMessenger.hideCurrentSnackBar();

    Color leftColor;
    IconData icon;
    
    switch (type) {
      case SnackBarType.success:
        leftColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case SnackBarType.error:
        leftColor = AppColors.danger;
        icon = Icons.error_outline;
        break;
      case SnackBarType.warning:
        leftColor = AppColors.warning;
        icon = Icons.warning_amber_outlined;
        break;
      case SnackBarType.info:
        leftColor = AppColors.primary;
        icon = Icons.info_outline;
        break;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: leftColor.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: leftColor.withOpacity(0.08),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 56,
                  color: leftColor,
                ),
                const SizedBox(width: 16),
                Icon(icon, color: leftColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                  onPressed: () {
                    scaffoldMessenger.hideCurrentSnackBar();
                  },
                ),
              ],
            ),
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
