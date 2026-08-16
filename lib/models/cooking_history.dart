import 'package:cloud_firestore/cloud_firestore.dart';

class CookingHistory {
  final String id;
  final String recipeId;
  final String recipeName;
  final String cookedBy;
  final String householdId;
  final DateTime cookedAt;
  final List<CookedIngredient> ingredients;
  final int servings;
  final double? estimatedMoneySaved;
  final double? estimatedCo2Saved;

  CookingHistory({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    required this.cookedBy,
    required this.householdId,
    required this.cookedAt,
    required this.ingredients,
    this.servings = 1,
    this.estimatedMoneySaved,
    this.estimatedCo2Saved,
  });

  factory CookingHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CookingHistory(
      id: doc.id,
      recipeId: data['recipeId'] ?? '',
      recipeName: data['recipeName'] ?? '',
      cookedBy: data['cookedBy'] ?? '',
      householdId: data['householdId'] ?? '',
      cookedAt: (data['cookedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ingredients: (data['ingredients'] as List<dynamic>?)
              ?.map((e) => CookedIngredient.fromMap(e))
              .toList() ??
          [],
      servings: data['servings'] ?? 1,
      estimatedMoneySaved: (data['estimatedMoneySaved'] as num?)?.toDouble(),
      estimatedCo2Saved: (data['estimatedCo2Saved'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'recipeName': recipeName,
      'cookedBy': cookedBy,
      'householdId': householdId,
      'cookedAt': FieldValue.serverTimestamp(),
      'ingredients': ingredients.map((e) => e.toMap()).toList(),
      'servings': servings,
      'estimatedMoneySaved': estimatedMoneySaved,
      'estimatedCo2Saved': estimatedCo2Saved,
    };
  }
}

class CookedIngredient {
  final String name;
  final double quantityConsumed;
  final String unit;
  final String? pantryItemId;

  CookedIngredient({
    required this.name,
    required this.quantityConsumed,
    required this.unit,
    this.pantryItemId,
  });

  factory CookedIngredient.fromMap(Map<String, dynamic> map) {
    return CookedIngredient(
      name: map['name'] ?? '',
      quantityConsumed: (map['quantityConsumed'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'pcs',
      pantryItemId: map['pantryItemId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantityConsumed': quantityConsumed,
      'unit': unit,
      'pantryItemId': pantryItemId,
    };
  }
}
