import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;
  final bool inPantry;

  RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.inPantry = false,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      inPantry: map['inPantry'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'inPantry': inPantry,
    };
  }
}

class Recipe {
  final String id;
  final String title;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String cuisine;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String? imageUrl;
  final String difficulty;
  final bool isAiGenerated;
  final DateTime createdAt;

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  bool get allIngredientsInPantry =>
      ingredients.every((i) => i.inPantry);

  int get missingIngredientCount =>
      ingredients.where((i) => !i.inPantry).length;

  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.steps,
    required this.cuisine,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    this.imageUrl,
    required this.difficulty,
    this.isAiGenerated = false,
    required this.createdAt,
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      title: data['title'] ?? '',
      ingredients: (data['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      steps: (data['steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      cuisine: data['cuisine'] ?? 'Other',
      prepTimeMinutes: data['prepTimeMinutes'] ?? 0,
      cookTimeMinutes: data['cookTimeMinutes'] ?? 0,
      servings: data['servings'] ?? 1,
      imageUrl: data['imageUrl'],
      difficulty: data['difficulty'] ?? 'Easy',
      isAiGenerated: data['isAiGenerated'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'ingredients': ingredients.map((e) => e.toMap()).toList(),
      'steps': steps,
      'cuisine': cuisine,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'servings': servings,
      'imageUrl': imageUrl,
      'difficulty': difficulty,
      'isAiGenerated': isAiGenerated,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
