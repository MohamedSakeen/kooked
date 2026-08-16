import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? householdId;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.householdId,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      householdId: data['householdId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'householdId': householdId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? householdId,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      householdId: householdId ?? this.householdId,
      createdAt: createdAt,
    );
  }
}
