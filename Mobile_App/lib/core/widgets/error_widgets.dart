import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RetryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const RetryButton({
    super.key,
    required this.onPressed,
    this.label = 'Try Again',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.refresh, size: 20),
      label: Text(label),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.iconColor = AppColors.danger,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 64),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              RetryButton(onPressed: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}

class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const NetworkErrorWidget({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorView(
      title: 'No Internet Connection',
      message: 'It looks like you are offline. Please check your connection and try again.',
      icon: Icons.wifi_off_outlined,
      iconColor: AppColors.primary,
      onRetry: onRetry,
    );
  }
}

class ServerErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ServerErrorWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorView(
      title: 'Server Unreachable',
      message: 'We are having trouble communicating with our servers. Please try again in a few moments.',
      icon: Icons.cloud_off_outlined,
      iconColor: AppColors.danger,
      onRetry: onRetry,
    );
  }
}

class SomethingWentWrongWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const SomethingWentWrongWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorView(
      title: 'Something Went Wrong',
      message: 'An unexpected error occurred. Please try again.',
      icon: Icons.error_outline_outlined,
      iconColor: AppColors.warning,
      onRetry: onRetry,
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateWidget({
    super.key,
    this.title = 'No Items Found',
    this.message = 'There is nothing to display here right now.',
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary.withOpacity(0.5), size: 72),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class NoDataWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoDataWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorView(
      title: 'No Data Available',
      message: 'The requested information could not be retrieved.',
      icon: Icons.analytics_outlined,
      iconColor: AppColors.textSecondary,
      onRetry: onRetry,
    );
  }
}

class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
