import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cooking_history.dart';
import '../models/pantry_item.dart';
import '../models/recipe.dart';
import 'api_service.dart';
import 'firestore_service.dart';

class CookingService {
  final ApiService _api = ApiService();
  final FirestoreService _firestore = FirestoreService();

  /// Step 1: Get AI consumption estimates for a recipe
  Future<List<CookedIngredient>> estimateConsumption({
    required Recipe recipe,
    required List<PantryItem> pantryItems,
    required int servings,
  }) async {
    final pantryMap = pantryItems.map((item) {
      return {
        'id': item.id,
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'category': item.category,
      };
    }).toList();

    final recipeMap = {
      'title': recipe.title,
      'ingredients': recipe.ingredients
          .map((i) => {
                'name': i.name,
                'quantity': i.quantity * servings,
                'unit': i.unit,
              })
          .toList(),
    };

    Map<String, dynamic> result;
    try {
      result = await _api.estimateConsumption(
        recipe: recipeMap,
        currentPantry: pantryMap,
      );
    } catch (_) {
      // Local fallback when API is offline or quota exceeded
      final fallbackConsumptions = recipe.ingredients.map((ing) {
        return {
          'name': ing.name,
          'quantityConsumed': ing.quantity * servings,
          'unit': ing.unit,
        };
      }).toList();
      result = {'consumptions': fallbackConsumptions};
    }

    final consumptions = result['consumptions'] as List<dynamic>? ?? [];

    return consumptions.map<CookedIngredient>((c) {
      final name = c['name'] ?? '';
      final qty = (c['quantityConsumed'] ?? 0).toDouble();
      final unit = c['unit'] ?? 'pcs';

      // Match to pantry item for ID reference
      PantryItem? match;
      try {
        match = pantryItems.firstWhere(
          (p) => p.name.toLowerCase().trim() == name.toLowerCase().trim(),
        );
      } catch (_) {}

      return CookedIngredient(
        name: name,
        quantityConsumed: qty,
        unit: unit,
        pantryItemId: match?.id,
      );
    }).toList();
  }

  /// Step 2: Apply confirmed consumption to pantry (deduct quantities)
  Future<void> applyCooking({
    required String householdId,
    required List<CookedIngredient> confirmedIngredients,
    required Recipe recipe,
    required String userId,
    required int servings,
    List<PantryItem>? pantryItems,
  }) async {
    // Build batch updates for pantry
    final updates = <Map<String, dynamic>>[];
    for (final ing in confirmedIngredients) {
      if (ing.pantryItemId == null) continue;

      PantryItem? pantryItem;
      try {
        pantryItem = pantryItems?.firstWhere(
          (p) => p.id == ing.pantryItemId,
        );
      } catch (_) {}

      if (pantryItem == null) continue;

      final newQty = pantryItem.quantity - ing.quantityConsumed;
      updates.add({
        'id': ing.pantryItemId,
        'quantity': newQty > 0 ? double.parse(newQty.toStringAsFixed(2)) : 0,
      });
    }

    if (updates.isNotEmpty) {
      await _firestore.batchUpdatePantry(householdId, updates);
    }

    // Log cooking history
    await _logCooking(
      householdId: householdId,
      recipe: recipe,
      userId: userId,
      servings: servings,
      ingredients: confirmedIngredients,
    );

    // Update sustainability stats
    await _updateStats(
      householdId: householdId,
      recipe: recipe,
      servings: servings,
      ingredientsUsed: confirmedIngredients,
    );
  }

  Future<void> _logCooking({
    required String householdId,
    required Recipe recipe,
    required String userId,
    required int servings,
    required List<CookedIngredient> ingredients,
  }) async {
    final history = CookingHistory(
      id: '',
      recipeId: recipe.id,
      recipeName: recipe.title,
      cookedBy: userId,
      householdId: householdId,
      cookedAt: DateTime.now(),
      ingredients: ingredients,
      servings: servings,
    );

    await FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .collection('cookingHistory')
        .add(history.toMap());
  }

  Future<void> _updateStats({
    required String householdId,
    required Recipe recipe,
    required int servings,
    required List<CookedIngredient> ingredientsUsed,
  }) async {
    final currentStats = await _firestore.getStats(householdId);

    final mealsCooked = (currentStats['mealsCooked'] ?? 0) + 1;
    final itemsUsed = (currentStats['itemsUsed'] ?? 0) + ingredientsUsed.length;

    // Rough estimate: each ingredient used saves ~$0.50 avg
    final moneySaved =
        (currentStats['moneySaved'] ?? 0.0) + (ingredientsUsed.length * 0.50);

    // CO2: ~0.5kg per meal saved from waste
    final co2Avoided =
        (currentStats['co2AvoidedKg'] ?? 0.0) + (0.5 * servings);

    // FWRS: based on meals cooked + items used ratio
    final fwrs = (mealsCooked * 10 + itemsUsed * 2).clamp(0, 100);

    await _firestore.updateStats(householdId, {
      'mealsCooked': mealsCooked,
      'itemsUsed': itemsUsed,
      'moneySaved': double.parse(moneySaved.toStringAsFixed(2)),
      'co2AvoidedKg': double.parse(co2Avoided.toStringAsFixed(2)),
      'fwrs': fwrs,
      'lastCookedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CookingHistory>> cookingHistoryStream(String householdId) {
    return FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .collection('cookingHistory')
        .orderBy('cookedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CookingHistory.fromFirestore(d)).toList());
  }
}
