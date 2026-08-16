import '../utils/constants.dart';
import '../models/pantry_item.dart';
import 'api_service.dart';

enum FoodClassificationSource {
  local,
  ai,
  userConfirmed,
  fallback,
}

class FoodClassificationResult {
  final String canonicalName;
  final String category;
  final String type;
  final double confidence;
  final FoodClassificationSource source;
  final bool isAmbiguous;

  const FoodClassificationResult({
    required this.canonicalName,
    required this.category,
    required this.type,
    required this.confidence,
    required this.source,
    this.isAmbiguous = false,
  });

  FoodClassificationResult copyWith({
    String? canonicalName,
    String? category,
    String? type,
    double? confidence,
    FoodClassificationSource? source,
    bool? isAmbiguous,
  }) {
    return FoodClassificationResult(
      canonicalName: canonicalName ?? this.canonicalName,
      category: category ?? this.category,
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      isAmbiguous: isAmbiguous ?? this.isAmbiguous,
    );
  }
}

class FoodClassificationService {
  final ApiService _apiService;

  FoodClassificationService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // ─── Layer 1: Normalization ──────────────────────────────────────────────

  /// Normalizes input string to canonical representation.
  static String normalizeName(String input) {
    String trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return '';

    // Remove extra spaces
    trimmed = trimmed.replaceAll(RegExp(r'\s+'), ' ');

    // Handle basic plural forms
    if (trimmed.endsWith('tomatoes')) {
      trimmed = trimmed.replaceAll('tomatoes', 'tomato');
    } else if (trimmed.endsWith('potatoes')) {
      trimmed = trimmed.replaceAll('potatoes', 'potato');
    } else if (trimmed.endsWith('cookies')) {
      trimmed = trimmed.replaceAll('cookies', 'cookie');
    } else if (trimmed.endsWith('berries')) {
      trimmed = trimmed.replaceAll('berries', 'berry');
    } else if (trimmed.endsWith('s') &&
        !trimmed.endsWith('ss') &&
        !trimmed.endsWith('us') &&
        !trimmed.endsWith('is') &&
        !trimmed.endsWith('peas') &&
        !trimmed.endsWith('crisps') &&
        !trimmed.endsWith('oats') &&
        !trimmed.endsWith('chips') &&
        !trimmed.endsWith('biscuits') &&
        !trimmed.endsWith('leftovers')) {
      // Remove trailing 's' if not a special word
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }

    return _toTitleCase(trimmed);
  }

  static String _toTitleCase(String text) {
    if (text.isEmpty) return '';
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // ─── Layer 2 & 3: Local Food Knowledge & Dish Recognizer ───────────────

  static final Map<String, ({String category, String type})> _localDictionary = {
    // Produce / Raw
    'tomato': (category: 'Produce', type: 'Raw'),
    'onion': (category: 'Produce', type: 'Raw'),
    'brinjal': (category: 'Produce', type: 'Raw'),
    'eggplant': (category: 'Produce', type: 'Raw'),
    'potato': (category: 'Produce', type: 'Raw'),
    'carrot': (category: 'Produce', type: 'Raw'),
    'garlic': (category: 'Produce', type: 'Raw'),
    'ginger': (category: 'Produce', type: 'Raw'),
    'spinach': (category: 'Produce', type: 'Raw'),
    'coriander': (category: 'Produce', type: 'Raw'),
    'apple': (category: 'Produce', type: 'Raw'),
    'banana': (category: 'Produce', type: 'Raw'),
    'lemon': (category: 'Produce', type: 'Raw'),
    'lime': (category: 'Produce', type: 'Raw'),
    'cucumber': (category: 'Produce', type: 'Raw'),
    'chili': (category: 'Produce', type: 'Raw'),
    'capsicum': (category: 'Produce', type: 'Raw'),
    'bell pepper': (category: 'Produce', type: 'Raw'),
    'broccoli': (category: 'Produce', type: 'Raw'),
    'cauliflower': (category: 'Produce', type: 'Raw'),
    'mushroom': (category: 'Produce', type: 'Raw'),
    'cabbage': (category: 'Produce', type: 'Raw'),
    'avocado': (category: 'Produce', type: 'Raw'),
    'orange': (category: 'Produce', type: 'Raw'),
    'strawberry': (category: 'Produce', type: 'Raw'),
    'grape': (category: 'Produce', type: 'Raw'),
    'mango': (category: 'Produce', type: 'Raw'),

    // Dairy / Packaged
    'milk': (category: 'Dairy', type: 'Packaged'),
    'cheese': (category: 'Dairy', type: 'Packaged'),
    'butter': (category: 'Dairy', type: 'Packaged'),
    'yogurt': (category: 'Dairy', type: 'Packaged'),
    'curd': (category: 'Dairy', type: 'Packaged'),
    'paneer': (category: 'Dairy', type: 'Packaged'),
    'cream': (category: 'Dairy', type: 'Packaged'),
    'ghee': (category: 'Dairy', type: 'Packaged'),

    // Meat & Seafood / Raw
    'raw chicken': (category: 'Meat & Seafood', type: 'Raw'),
    'chicken breast': (category: 'Meat & Seafood', type: 'Raw'),
    'chicken thigh': (category: 'Meat & Seafood', type: 'Raw'),
    'beef': (category: 'Meat & Seafood', type: 'Raw'),
    'pork': (category: 'Meat & Seafood', type: 'Raw'),
    'mutton': (category: 'Meat & Seafood', type: 'Raw'),
    'lamb': (category: 'Meat & Seafood', type: 'Raw'),
    'fish': (category: 'Meat & Seafood', type: 'Raw'),
    'salmon': (category: 'Meat & Seafood', type: 'Raw'),
    'shrimp': (category: 'Meat & Seafood', type: 'Raw'),
    'prawn': (category: 'Meat & Seafood', type: 'Raw'),

    // Grains & Bread / Packaged
    'bread': (category: 'Grains & Bread', type: 'Packaged'),
    'white bread': (category: 'Grains & Bread', type: 'Packaged'),
    'brown bread': (category: 'Grains & Bread', type: 'Packaged'),
    'basmati rice': (category: 'Grains & Bread', type: 'Packaged'),
    'jasmine rice': (category: 'Grains & Bread', type: 'Packaged'),
    'brown rice': (category: 'Grains & Bread', type: 'Packaged'),
    'raw rice': (category: 'Grains & Bread', type: 'Packaged'),
    'oats': (category: 'Grains & Bread', type: 'Packaged'),
    'flour': (category: 'Grains & Bread', type: 'Packaged'),
    'wheat flour': (category: 'Grains & Bread', type: 'Packaged'),
    'atta': (category: 'Grains & Bread', type: 'Packaged'),
    'quinoa': (category: 'Grains & Bread', type: 'Packaged'),

    // Canned & Jarred / Packaged
    'canned tomato': (category: 'Canned & Jarred', type: 'Packaged'),
    'canned bean': (category: 'Canned & Jarred', type: 'Packaged'),
    'canned tuna': (category: 'Canned & Jarred', type: 'Packaged'),
    'coconut milk': (category: 'Canned & Jarred', type: 'Packaged'),
    'tomato paste': (category: 'Canned & Jarred', type: 'Packaged'),
    'jam': (category: 'Canned & Jarred', type: 'Packaged'),
    'peanut butter': (category: 'Canned & Jarred', type: 'Packaged'),

    // Spices & Seasonings / Packaged
    'salt': (category: 'Spices & Seasonings', type: 'Packaged'),
    'black pepper': (category: 'Spices & Seasonings', type: 'Packaged'),
    'turmeric': (category: 'Spices & Seasonings', type: 'Packaged'),
    'chili powder': (category: 'Spices & Seasonings', type: 'Packaged'),
    'cumin': (category: 'Spices & Seasonings', type: 'Packaged'),
    'garam masala': (category: 'Spices & Seasonings', type: 'Packaged'),
    'cinnamon': (category: 'Spices & Seasonings', type: 'Packaged'),

    // Oils & Condiments / Packaged
    'cooking oil': (category: 'Oils & Condiments', type: 'Packaged'),
    'olive oil': (category: 'Oils & Condiments', type: 'Packaged'),
    'vegetable oil': (category: 'Oils & Condiments', type: 'Packaged'),
    'mustard oil': (category: 'Oils & Condiments', type: 'Packaged'),
    'soy sauce': (category: 'Oils & Condiments', type: 'Packaged'),
    'tomato sauce': (category: 'Oils & Condiments', type: 'Packaged'),
    'ketchup': (category: 'Oils & Condiments', type: 'Packaged'),
    'vinegar': (category: 'Oils & Condiments', type: 'Packaged'),
    'mayonnaise': (category: 'Oils & Condiments', type: 'Packaged'),

    // Frozen / Packaged
    'frozen pea': (category: 'Frozen', type: 'Packaged'),
    'frozen corn': (category: 'Frozen', type: 'Packaged'),
    'frozen berry': (category: 'Frozen', type: 'Packaged'),
    'ice cream': (category: 'Frozen', type: 'Packaged'),

    // Beverages / Packaged
    'coffee': (category: 'Beverages', type: 'Packaged'),
    'tea': (category: 'Beverages', type: 'Packaged'),
    'juice': (category: 'Beverages', type: 'Packaged'),
    'orange juice': (category: 'Beverages', type: 'Packaged'),
    'soda': (category: 'Beverages', type: 'Packaged'),

    // Snacks / Packaged
    'biscuits': (category: 'Snacks', type: 'Packaged'),
    'biscuit': (category: 'Snacks', type: 'Packaged'),
    'chips': (category: 'Snacks', type: 'Packaged'),
    'potato chips': (category: 'Snacks', type: 'Packaged'),
    'cracker': (category: 'Snacks', type: 'Packaged'),
    'cookie': (category: 'Snacks', type: 'Packaged'),
    'nut': (category: 'Snacks', type: 'Packaged'),
    'popcorn': (category: 'Snacks', type: 'Packaged'),
    'chocolate': (category: 'Snacks', type: 'Packaged'),
  };

  static const List<String> _ambiguousTerms = [
    'rice',
    'chicken',
    'egg',
    'pasta',
    'noodle',
    'fish',
  ];

  static const List<String> _leftoverKeywords = [
    'curry',
    'sambar',
    'rasam',
    'biryani',
    'korma',
    'dal',
    'stew',
    'soup',
    'gravy',
    'sabzi',
    'fried rice',
    'cooked rice',
    'tomato rice',
    'lemon rice',
    'curd rice',
    'chapati',
    'roti',
    'naan',
    'pepper fry',
    'stir fry',
    'casserole',
    'leftover',
    'cooked',
  ];

  /// Core classification method.
  Future<FoodClassificationResult> classify(String rawName, {bool isOnline = true}) async {
    final canonicalName = normalizeName(rawName);
    if (canonicalName.isEmpty) {
      return const FoodClassificationResult(
        canonicalName: '',
        category: 'Other',
        type: 'Raw',
        confidence: 0.0,
        source: FoodClassificationSource.fallback,
      );
    }

    final lower = canonicalName.toLowerCase();

    // Check ambiguous terms first
    if (_ambiguousTerms.contains(lower)) {
      final defaultMapping = _localDictionary[lower];
      return FoodClassificationResult(
        canonicalName: canonicalName,
        category: defaultMapping?.category ?? 'Other',
        type: defaultMapping?.type ?? 'Raw',
        confidence: 0.5,
        source: FoodClassificationSource.local,
        isAmbiguous: true,
      );
    }

    // Check Layer 3: Prepared / Leftover Dish Recognition
    for (final keyword in _leftoverKeywords) {
      if (lower.contains(keyword)) {
        return FoodClassificationResult(
          canonicalName: canonicalName,
          category: 'Leftovers',
          type: 'Leftover',
          confidence: 0.95,
          source: FoodClassificationSource.local,
        );
      }
    }

    // Check Layer 2: Local Dictionary
    if (_localDictionary.containsKey(lower)) {
      final item = _localDictionary[lower]!;
      return FoodClassificationResult(
        canonicalName: canonicalName,
        category: item.category,
        type: item.type,
        confidence: 0.95,
        source: FoodClassificationSource.local,
      );
    }

    // Check partial dictionary match
    for (final entry in _localDictionary.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return FoodClassificationResult(
          canonicalName: canonicalName,
          category: entry.value.category,
          type: entry.value.type,
          confidence: 0.85,
          source: FoodClassificationSource.local,
        );
      }
    }

    // Layer 4: AI Fallback (if online)
    if (isOnline) {
      try {
        final aiResult = await _apiService.classifyFoodItem(canonicalName);
        if (aiResult != null) {
          final cat = AppConstants.pantryCategories.contains(aiResult['category'])
              ? aiResult['category'] as String
              : 'Other';
          final typ = AppConstants.itemTypes.contains(aiResult['type'])
              ? aiResult['type'] as String
              : 'Raw';
          final confidence = (aiResult['confidence'] as num?)?.toDouble() ?? 0.8;

          return FoodClassificationResult(
            canonicalName: aiResult['canonicalName'] ?? canonicalName,
            category: cat,
            type: typ,
            confidence: confidence,
            source: FoodClassificationSource.ai,
          );
        }
      } catch (_) {
        // AI call failed or timed out — fall through to Layer 5
      }
    }

    // Layer 5: Safe Offline Fallback
    return FoodClassificationResult(
      canonicalName: canonicalName,
      category: 'Other',
      type: 'Raw',
      confidence: 0.4,
      source: FoodClassificationSource.fallback,
    );
  }

  /// Duplicate Detection Helper: Searches existing pantry items for duplicate canonical match.
  static PantryItem? findDuplicate(String inputName, List<PantryItem> pantryItems) {
    final canonicalInput = normalizeName(inputName).toLowerCase();
    if (canonicalInput.isEmpty) return null;

    for (final item in pantryItems) {
      final canonicalItem = normalizeName(item.name).toLowerCase();
      if (canonicalItem == canonicalInput) {
        return item;
      }
    }
    return null;
  }
}
