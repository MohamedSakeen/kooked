import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool isChecked;
  final String? addedFromRecipeId;
  final String householdId;

  ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.isChecked = false,
    this.addedFromRecipeId,
    required this.householdId,
  });

  factory ShoppingItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShoppingItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: (data['quantity'] ?? 1).toDouble(),
      unit: data['unit'] ?? 'pcs',
      isChecked: data['isChecked'] ?? false,
      addedFromRecipeId: data['addedFromRecipeId'],
      householdId: data['householdId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isChecked': isChecked,
      'addedFromRecipeId': addedFromRecipeId,
      'householdId': householdId,
    };
  }

  ShoppingItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    bool? isChecked,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      addedFromRecipeId: addedFromRecipeId,
      householdId: householdId,
    );
  }
}
