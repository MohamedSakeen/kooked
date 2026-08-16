class AppConstants {
  AppConstants._();

  static const String appName = 'KooKed';
  static const String appTagline = 'Cook What You Have.';

  static const List<String> pantryCategories = [
    'Produce',
    'Dairy',
    'Meat & Seafood',
    'Grains & Bread',
    'Canned & Jarred',
    'Spices & Seasonings',
    'Oils & Condiments',
    'Frozen',
    'Beverages',
    'Snacks',
    'Leftovers',
    'Other',
  ];

  static const List<String> itemTypes = [
    'Raw',
    'Packaged',
    'Leftover',
  ];

  static const List<String> cuisineTypes = [
    'Indian',
    'Italian',
    'Mexican',
    'Chinese',
    'Japanese',
    'Thai',
    'Mediterranean',
    'American',
    'French',
    'Korean',
    'Middle Eastern',
    'African',
    'Other',
  ];

  static const List<String> difficultyLevels = [
    'Easy',
    'Medium',
    'Hard',
  ];

  static const Map<String, String> categoryIcons = {
    'Produce': '🥬',
    'Dairy': '🥛',
    'Meat & Seafood': '🥩',
    'Grains & Bread': '🌾',
    'Canned & Jarred': '🥫',
    'Spices & Seasonings': '🧂',
    'Oils & Condiments': '🫒',
    'Frozen': '🧊',
    'Beverages': '🥤',
    'Snacks': '🍿',
    'Leftovers': '🍲',
    'Other': '📦',
  };
}
