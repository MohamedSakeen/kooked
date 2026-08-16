import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/constants.dart';

class PantryCard extends StatelessWidget {
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final String type;
  final DateTime dateAdded;
  final String? imageUrl;
  final VoidCallback? onTap;

  const PantryCard({
    super.key,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.dateAdded,
    this.imageUrl,
    this.onTap,
  });

  Color get _typeColor {
    switch (type) {
      case 'Raw':
        return AppColors.typeRaw;
      case 'Packaged':
        return AppColors.typePackaged;
      case 'Leftover':
        return AppColors.typeLeftover;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _categoryEmoji =>
      AppConstants.categoryIcons[category] ?? '📦';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _categoryEmoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$category · ${_formatDate(dateAdded)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${quantity % 1 == 0 ? quantity.toInt() : quantity} $unit',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: _typeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 30) return '${(diff / 7).floor()}w ago';
    return '${(diff / 30).floor()}mo ago';
  }
}
