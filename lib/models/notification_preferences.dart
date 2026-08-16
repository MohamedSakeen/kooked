class NotificationPreferences {
  final bool expiryAlerts;
  final bool recipeSuggestions;
  final bool shoppingReminders;
  final bool wasteTips;
  final bool cookingReminders;

  NotificationPreferences({
    required this.expiryAlerts,
    required this.recipeSuggestions,
    required this.shoppingReminders,
    required this.wasteTips,
    required this.cookingReminders,
  });

  factory NotificationPreferences.defaults() {
    return NotificationPreferences(
      expiryAlerts: true,
      recipeSuggestions: true,
      shoppingReminders: true,
      wasteTips: false,
      cookingReminders: true,
    );
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      expiryAlerts: map['expiryAlerts'] ?? true,
      recipeSuggestions: map['recipeSuggestions'] ?? true,
      shoppingReminders: map['shoppingReminders'] ?? true,
      wasteTips: map['wasteTips'] ?? false,
      cookingReminders: map['cookingReminders'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expiryAlerts': expiryAlerts,
      'recipeSuggestions': recipeSuggestions,
      'shoppingReminders': shoppingReminders,
      'wasteTips': wasteTips,
      'cookingReminders': cookingReminders,
    };
  }

  NotificationPreferences copyWith({
    bool? expiryAlerts,
    bool? recipeSuggestions,
    bool? shoppingReminders,
    bool? wasteTips,
    bool? cookingReminders,
  }) {
    return NotificationPreferences(
      expiryAlerts: expiryAlerts ?? this.expiryAlerts,
      recipeSuggestions: recipeSuggestions ?? this.recipeSuggestions,
      shoppingReminders: shoppingReminders ?? this.shoppingReminders,
      wasteTips: wasteTips ?? this.wasteTips,
      cookingReminders: cookingReminders ?? this.cookingReminders,
    );
  }
}
