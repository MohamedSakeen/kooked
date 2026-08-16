import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';
import '../../services/cooking_service.dart';
import '../../models/cooking_history.dart';

class SustainabilityScreen extends StatelessWidget {
  const SustainabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final householdId = FirebaseAuth.instance.currentUser?.uid ?? 'demo';
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: firestore.getStats(householdId),
        builder: (context, statsSnap) {
          final stats = statsSnap.data ?? {
            'mealsCooked': 0,
            'foodSavedKg': 0.0,
            'moneySaved': 0.0,
            'co2AvoidedKg': 0.0,
            'fwrs': 0,
            'itemsUsed': 0,
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFWRSHeader(context, stats),
              const SizedBox(height: 20),
              _buildStatsGrid(context, stats),
              const SizedBox(height: 20),
              _buildCookingHistory(context, householdId),
              const SizedBox(height: 20),
              _buildAchievements(context, stats),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFWRSHeader(BuildContext context, Map<String, dynamic> stats) {
    final fwrs = (stats['fwrs'] ?? 0) as int;
    final mealsCooked = (stats['mealsCooked'] ?? 0) as int;
    final fwrsValue = fwrs / 100;

    String message;
    if (mealsCooked == 0) {
      message = 'Cook your first meal to start tracking your score!';
    } else if (fwrs >= 70) {
      message = "Great job! You're reducing food waste effectively.";
    } else if (fwrs >= 40) {
      message = "Good progress! Keep cooking to improve your score.";
    } else {
      message = "Start cooking to reduce food waste and boost your score.";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: fwrsValue.clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accentLight,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$fwrs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'FWRS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Food Waste\nReduction Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    final statsData = [
      {
        'icon': Icons.restaurant,
        'label': 'Meals Cooked',
        'value': '${stats['mealsCooked'] ?? 0}',
        'color': AppColors.primary
      },
      {
        'icon': Icons.eco,
        'label': 'Food Saved (kg)',
        'value': '${(stats['foodSavedKg'] ?? 0.0).toStringAsFixed(1)}',
        'color': AppColors.success
      },
      {
        'icon': Icons.savings,
        'label': 'Money Saved',
        'value': '\$${(stats['moneySaved'] ?? 0.0).toStringAsFixed(0)}',
        'color': AppColors.accent
      },
      {
        'icon': Icons.cloud,
        'label': 'CO\u2082 Avoided (kg)',
        'value': '${(stats['co2AvoidedKg'] ?? 0.0).toStringAsFixed(1)}',
        'color': AppColors.typePackaged
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: statsData.length,
      itemBuilder: (context, index) {
        final s = statsData[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(s['icon'] as IconData, size: 20, color: s['color'] as Color),
              const Spacer(),
              Text(
                s['value'] as String,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: s['color'] as Color,
                ),
              ),
              Text(
                s['label'] as String,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCookingHistory(BuildContext context, String householdId) {
    final cookingService = CookingService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Cooking', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        StreamBuilder<List<CookingHistory>>(
          stream: cookingService.cookingHistoryStream(householdId),
          builder: (context, snapshot) {
            final history = snapshot.data ?? [];

            if (history.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 36, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text(
                      'No meals cooked yet',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    Text(
                      'Cook a recipe to start tracking!',
                      style:
                          TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: history.take(5).map((h) {
                final timeAgo = _getTimeAgo(h.cookedAt);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.restaurant,
                            size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.recipeName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              '${h.servings} serving${h.servings > 1 ? 's' : ''} • ${h.ingredients.length} ingredients',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Widget _buildAchievements(BuildContext context, Map<String, dynamic> stats) {
    final mealsCooked = (stats['mealsCooked'] ?? 0) as int;
    final itemsUsed = (stats['itemsUsed'] ?? 0) as int;
    final moneySaved = (stats['moneySaved'] ?? 0.0);

    final achievements = [
      {'icon': '🌱', 'title': 'First Meal', 'subtitle': 'Cooked your first meal', 'unlocked': mealsCooked >= 1},
      {'icon': '🔥', 'title': 'Home Chef', 'subtitle': 'Cooked 5 meals', 'unlocked': mealsCooked >= 5},
      {'icon': '♻️', 'title': 'Ingredient Master', 'subtitle': 'Used 20 ingredients', 'unlocked': itemsUsed >= 20},
      {'icon': '💰', 'title': 'Smart Saver', 'subtitle': 'Saved \$50+ on groceries', 'unlocked': moneySaved >= 50},
      {'icon': '👨‍🍳', 'title': 'Recipe Explorer', 'subtitle': 'Cooked 10 different meals', 'unlocked': mealsCooked >= 10},
      {'icon': '🌍', 'title': 'Eco Warrior', 'subtitle': 'Cooked 25 meals', 'unlocked': mealsCooked >= 25},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        ...achievements.map((a) {
          final unlocked = a['unlocked'] as bool;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.accentLight.withValues(alpha: 0.1)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: unlocked
                    ? AppColors.accentLight.withValues(alpha: 0.3)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Text(
                  a['icon'] as String,
                  style: TextStyle(
                    fontSize: 24,
                    color: unlocked ? null : AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: unlocked
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                      Text(
                        a['subtitle'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unlocked)
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20)
                else
                  const Icon(Icons.lock_outline,
                      color: AppColors.textHint, size: 20),
              ],
            ),
          );
        }),
      ],
    );
  }
}
