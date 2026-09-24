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
    final rawQty = map['quantity'];
    double qty = 0.0;
    if (rawQty is num) {
      qty = rawQty.toDouble();
    } else if (rawQty != null) {
      qty = double.tryParse(rawQty.toString()) ?? 0.0;
    }
    return RecipeIngredient(
      name: map['name'] ?? '',
      quantity: qty,
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
    final rawPrep = data['prepTimeMinutes'];
    final rawCook = data['cookTimeMinutes'];
    final rawServings = data['servings'];

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
      prepTimeMinutes: (rawPrep is num)
          ? rawPrep.toInt()
          : int.tryParse(rawPrep?.toString() ?? '') ?? 0,
      cookTimeMinutes: (rawCook is num)
          ? rawCook.toInt()
          : int.tryParse(rawCook?.toString() ?? '') ?? 0,
      servings: (rawServings is num)
          ? rawServings.toInt()
          : int.tryParse(rawServings?.toString() ?? '') ?? 1,
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
