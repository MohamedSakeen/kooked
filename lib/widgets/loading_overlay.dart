import 'package:flutter/material.dart';
import '../config/theme.dart';

class LoadingOverlay extends StatelessWidget {
  final String? message;

  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
