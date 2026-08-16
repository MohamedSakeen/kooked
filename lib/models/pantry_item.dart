import 'package:cloud_firestore/cloud_firestore.dart';

class PantryItem {
  final String id;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final String type;
  final DateTime dateAdded;
  final String? imageUrl;
  final String addedBy;
  final String householdId;

  PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.dateAdded,
    this.imageUrl,
    required this.addedBy,
    required this.householdId,
  });

  factory PantryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PantryItem(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Other',
      quantity: (data['quantity'] ?? 0).toDouble(),
      unit: data['unit'] ?? 'pcs',
      type: data['type'] ?? 'Raw',
      dateAdded: (data['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'],
      addedBy: data['addedBy'] ?? '',
      householdId: data['householdId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'type': type,
      'dateAdded': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
      'addedBy': addedBy,
      'householdId': householdId,
    };
  }

  PantryItem copyWith({
    String? name,
    String? category,
    double? quantity,
    String? unit,
    String? type,
    String? imageUrl,
  }) {
    return PantryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      dateAdded: dateAdded,
      imageUrl: imageUrl ?? this.imageUrl,
      addedBy: addedBy,
      householdId: householdId,
    );
  }
}
