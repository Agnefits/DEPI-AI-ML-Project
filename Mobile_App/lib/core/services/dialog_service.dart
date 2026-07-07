import 'package:flutter/material.dart';
import '../routing/app_router.dart';
import '../theme/app_colors.dart';

class DialogService {
  static Future<T?> showCustomDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
  }) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return Future.value(null);

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.background.withOpacity(0.8),
      builder: (BuildContext context) {
        return child;
      },
    );
  }

  static void showErrorDialog({
    required String title,
    required String message,
    String buttonText = 'Dismiss',
    VoidCallback? onPressed,
  }) {
    showCustomDialog(
      child: _BaseDialog(
        title: title,
        message: message,
        confirmText: buttonText,
        confirmColor: AppColors.danger,
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        onConfirm: () {
          Navigator.of(AppRouter.navigatorKey.currentContext!).pop();
          onPressed?.call();
        },
      ),
    );
  }

  static void showSuccessDialog({
    required String title,
    required String message,
    String buttonText = 'Continue',
    VoidCallback? onPressed,
  }) {
    showCustomDialog(
      child: _BaseDialog(
        title: title,
        message: message,
        confirmText: buttonText,
        confirmColor: AppColors.success,
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        onConfirm: () {
          Navigator.of(AppRouter.navigatorKey.currentContext!).pop();
          onPressed?.call();
        },
      ),
    );
  }

  static void showConfirmationDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    showCustomDialog(
      child: _BaseDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: AppColors.primary,
        icon: Icons.help_outline,
        iconColor: AppColors.primary,
        onConfirm: () {
          Navigator.of(AppRouter.navigatorKey.currentContext!).pop();
          onConfirm();
        },
        onCancel: () {
          Navigator.of(AppRouter.navigatorKey.currentContext!).pop();
          onCancel?.call();
        },
      ),
    );
  }

  static void showDeleteDialog({
    required String title,
    required String message,
    String confirmText = 'Delete',
    String cancelText = 'Cancel',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    showCustomDialog(
      child: _BaseDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: AppColors.danger,
        icon: Icons.delete_outline,
        iconColor: AppColors.danger,
        onConfirm: () {
          Navigator.of(AppRouter.navigatorKey.currentContext!).pop();
          onConfirm();
        },
        onCancel: () {
          Navigator.of(AppRouter.navigatorKey.currentContext!).pop();
          onCancel?.call();
        },
      ),
    );
  }

  static void showSessionExpiredDialog({
    required VoidCallback onLoginRedirect,
  }) {
    showCustomDialog(
      barrierDismissible: false,
      child: _BaseDialog(
        title: 'Session Expired',
        message: 'Your session has expired. Please log in again to continue.',
        confirmText: 'Log In',
        confirmColor: AppColors.primary,
        icon: Icons.lock_clock_outlined,
        iconColor: AppColors.warning,
        onConfirm: () {
          Navigator.of(AppRouter.navigatorKey.currentContext!).pop();
          onLoginRedirect();
        },
      ),
    );
  }
}

class _BaseDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final Color confirmColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const _BaseDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText,
    required this.confirmColor,
    required this.icon,
    required this.iconColor,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (cancelText != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onCancel,
                      child: Text(cancelText!),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onConfirm,
                    child: Text(confirmText),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
