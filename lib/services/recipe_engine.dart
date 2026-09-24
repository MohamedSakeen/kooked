import '../models/recipe.dart';
import '../models/pantry_item.dart';

class RecipeMatchingResult {
  final Recipe recipe;
  final bool allInPantry;
  final int missingCount;
  final int availableCount;
  final List<RecipeIngredient> missingIngredients;
  final double matchScore;

  RecipeMatchingResult({
    required this.recipe,
    required this.allInPantry,
    required this.missingCount,
    required this.availableCount,
    required this.missingIngredients,
    required this.matchScore,
  });
}

class RecipeEngine {
  /// Matches pantry items against a list of recipes and returns sorted results.
  /// Prioritizes by:
  /// 1. Cook Now (all ingredients available) — sorted by FIFO (dateAdded)
  /// 2. Almost There (missing 1-3 items) — sorted by match score
  /// 3. Far Off (missing 4+ items) — excluded
  static List<RecipeMatchingResult> matchRecipes({
    required List<Recipe> recipes,
    required List<PantryItem> pantryItems,
  }) {
    final pantryNames = pantryItems
        .map((item) => item.name.toLowerCase().trim())
        .toSet();

    final pantryDateMap = <String, DateTime>{};
    for (final item in pantryItems) {
      final key = item.name.toLowerCase().trim();
      if (!pantryDateMap.containsKey(key) ||
          item.dateAdded.isAfter(pantryDateMap[key]!)) {
        pantryDateMap[key] = item.dateAdded;
      }
    }

    final results = <RecipeMatchingResult>[];

    for (final recipe in recipes) {
      final missing = <RecipeIngredient>[];
      var availableCount = 0;

      for (final ingredient in recipe.ingredients) {
        final ingName = ingredient.name.toLowerCase().trim();
        final inPantry = pantryNames.contains(ingName);

        if (inPantry) {
          availableCount++;
        } else {
          missing.add(RecipeIngredient(
            name: ingredient.name,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            inPantry: false,
          ));
        }
      }

      final missingCount = missing.length;
      final totalIngredients = recipe.ingredients.length;
      final allInPantry = missingCount == 0;
      // Match score: fraction of ingredients available in pantry (0.0 to 1.0)
      final matchScore = totalIngredients > 0
          ? (availableCount / totalIngredients)
          : 0.0;

      // Only include Cook Now and Almost There (missing <= 5 ingredients)
      if (missingCount > 5) continue;

      // Mark available ingredients
      final enrichedIngredients = recipe.ingredients.map((ing) {
        return RecipeIngredient(
          name: ing.name,
          quantity: ing.quantity,
          unit: ing.unit,
          inPantry: pantryNames.contains(ing.name.toLowerCase().trim()),
        );
      }).toList();

      results.add(RecipeMatchingResult(
        recipe: Recipe(
          id: recipe.id,
          title: recipe.title,
          ingredients: enrichedIngredients,
          steps: recipe.steps,
          cuisine: recipe.cuisine,
          prepTimeMinutes: recipe.prepTimeMinutes,
          cookTimeMinutes: recipe.cookTimeMinutes,
          servings: recipe.servings,
          imageUrl: recipe.imageUrl,
          difficulty: recipe.difficulty,
          isAiGenerated: recipe.isAiGenerated,
          createdAt: recipe.createdAt,
        ),
        allInPantry: allInPantry,
        missingCount: missingCount,
        availableCount: availableCount,
        missingIngredients: missing,
        matchScore: matchScore,
      ));
    }

    // Sort: Cook Now first (by FIFO dateAdded), then Almost There (by matchScore)
    results.sort((a, b) {
      if (a.allInPantry && !b.allInPantry) return -1;
      if (!a.allInPantry && b.allInPantry) return 1;

      if (a.allInPantry && b.allInPantry) {
        // FIFO: prefer recipes using older ingredients first
        final aDate = _oldestIngredientDate(a.recipe, pantryDateMap);
        final bDate = _oldestIngredientDate(b.recipe, pantryDateMap);
        return aDate.compareTo(bDate);
      }

      // For non-complete matches, prefer higher match score
      return b.matchScore.compareTo(a.matchScore);
    });

    return results;
  }

  static DateTime _oldestIngredientDate(
      Recipe recipe, Map<String, DateTime> dateMap) {
    var oldest = DateTime.now();
    for (final ing in recipe.ingredients) {
      final date = dateMap[ing.name.toLowerCase().trim()];
      if (date != null && date.isBefore(oldest)) {
        oldest = date;
      }
    }
    return oldest;
  }

  /// Gets missing ingredients for a specific recipe
  static List<RecipeIngredient> getMissingIngredients({
    required Recipe recipe,
    required List<PantryItem> pantryItems,
  }) {
    final pantryNames = pantryItems
        .map((item) => item.name.toLowerCase().trim())
        .toSet();

    return recipe.ingredients
        .where((ing) => !pantryNames.contains(ing.name.toLowerCase().trim()))
        .toList();
  }

  /// Checks if recipe is "Cook Now"
  static bool isCookNow({
    required Recipe recipe,
    required List<PantryItem> pantryItems,
  }) {
    final pantryNames = pantryItems
        .map((item) => item.name.toLowerCase().trim())
        .toSet();

    return recipe.ingredients
        .every((ing) => pantryNames.contains(ing.name.toLowerCase().trim()));
  }
}
