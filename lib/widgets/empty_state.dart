import 'package:flutter/material.dart';
import '../config/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
