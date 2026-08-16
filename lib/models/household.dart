import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  final String id;
  final String name;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;

  Household({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
  });

  factory Household.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Household(
      id: doc.id,
      name: data['name'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
