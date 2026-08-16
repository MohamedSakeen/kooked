import 'package:flutter/material.dart';
import '../config/theme.dart';

class QuantitySelector extends StatelessWidget {
  final double quantity;
  final String unit;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.unit,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 999,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            icon: Icons.remove,
            onTap: () {
              final newQty = (quantity - step).clamp(min, max);
              if (newQty != quantity) onChanged(newQty);
            },
          ),
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  quantity % 1 == 0
                      ? quantity.toInt().toString()
                      : quantity.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildButton(
            icon: Icons.add,
            onTap: () {
              final newQty = (quantity + step).clamp(min, max);
              if (newQty != quantity) onChanged(newQty);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
