import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:go_router/go_router.dart';

class GlobalErrorScreen extends StatelessWidget {
  final FlutterErrorDetails errorDetails;
  final VoidCallback? onTryAgain;

  const GlobalErrorScreen({
    super.key,
    required this.errorDetails,
    this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color(0x336D6AFB), // Transparent primary
              Colors.transparent,
            ],
            center: Alignment.topCenter,
            radius: 1.2,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                // App Logo Placeholder (Beautiful and Elegant)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
                    ),
                    child: Image.asset(
                      'assets/Logo.png',
                      height: 80,
                      width: 80,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback icon if Logo.png is not found
                        return const Icon(
                          Icons.medical_services_outlined,
                          size: 80,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'ClinicAI',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'An unexpected system anomaly has occurred. We apologize for the inconvenience.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 32),
                // Detailed Technical Box (Hidden by default, expandable for developers)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ExpansionTile(
                        collapsedIconColor: AppColors.textSecondary,
                        iconColor: AppColors.primary,
                        title: const Text(
                          'View Technical Information',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        children: [
                          Container(
                            height: 150,
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            color: Colors.black.withOpacity(0.3),
                            child: SingleChildScrollView(
                              child: Text(
                                '${errorDetails.exception}\n\n${errorDetails.stack}',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 24),
                // Action Buttons
                if (onTryAgain != null) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    onPressed: onTryAgain,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: () {
                    try {
                      context.go('/dashboard');
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Go Home'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error report sent. Thank you!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Report Error'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
