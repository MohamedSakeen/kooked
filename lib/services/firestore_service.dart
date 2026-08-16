import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pantry_item.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../models/household.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Pantry ──────────────────────────────────────────────────────

  CollectionReference _pantryRef(String householdId) =>
      _db.collection('households').doc(householdId).collection('pantry');

  Stream<List<PantryItem>> pantryStream(String householdId) {
    return _pantryRef(householdId)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PantryItem.fromFirestore(d)).toList());
  }

  Future<List<PantryItem>> getPantryItems(String householdId) async {
    final snap = await _pantryRef(householdId)
        .orderBy('dateAdded', descending: true)
        .get();
    return snap.docs.map((d) => PantryItem.fromFirestore(d)).toList();
  }

  Future<String> addPantryItem(String householdId, PantryItem item) async {
    final doc = await _pantryRef(householdId).add(item.toMap());
    return doc.id;
  }

  Future<void> updatePantryItem(
      String householdId, String itemId, Map<String, dynamic> data) async {
    await _pantryRef(householdId).doc(itemId).update(data);
  }

  Future<void> deletePantryItem(String householdId, String itemId) async {
    await _pantryRef(householdId).doc(itemId).delete();
  }

  Future<void> batchUpdatePantry(
    String householdId,
    List<Map<String, dynamic>> updates,
  ) async {
    final batch = _db.batch();
    for (final update in updates) {
      final ref = _pantryRef(householdId).doc(update['id']);
      if ((update['quantity'] ?? 0) <= 0) {
        batch.delete(ref);
      } else {
        batch.update(ref, {'quantity': update['quantity']});
      }
    }
    await batch.commit();
  }

  // ─── Recipes ─────────────────────────────────────────────────────

  CollectionReference get _recipesRef => _db.collection('recipes');

  Stream<List<Recipe>> recipesStream() {
    return _recipesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Recipe.fromFirestore(d)).toList());
  }

  Future<List<Recipe>> getRecipes() async {
    final snap = await _recipesRef.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => Recipe.fromFirestore(d)).toList();
  }

  Future<Recipe?> getRecipe(String recipeId) async {
    final doc = await _recipesRef.doc(recipeId).get();
    if (!doc.exists) return null;
    return Recipe.fromFirestore(doc);
  }

  Future<String> addRecipe(Recipe recipe) async {
    final doc = await _recipesRef.add(recipe.toMap());
    return doc.id;
  }

  // ─── Shopping List ───────────────────────────────────────────────

  CollectionReference _shoppingRef(String householdId) =>
      _db.collection('households').doc(householdId).collection('shoppingList');

  Stream<List<ShoppingItem>> shoppingStream(String householdId) {
    return _shoppingRef(householdId)
        .orderBy('isChecked')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ShoppingItem.fromFirestore(d)).toList());
  }

  Future<String> addShoppingItem(
      String householdId, ShoppingItem item) async {
    final doc = await _shoppingRef(householdId).add(item.toMap());
    return doc.id;
  }

  Future<void> updateShoppingItem(
      String householdId, String itemId, Map<String, dynamic> data) async {
    await _shoppingRef(householdId).doc(itemId).update(data);
  }

  Future<void> deleteShoppingItem(String householdId, String itemId) async {
    await _shoppingRef(householdId).doc(itemId).delete();
  }

  Future<void> batchAddShoppingItems(
    String householdId,
    List<ShoppingItem> items,
  ) async {
    final batch = _db.batch();
    for (final item in items) {
      final ref = _shoppingRef(householdId).doc();
      batch.set(ref, item.toMap());
    }
    await batch.commit();
  }

  // ─── Household ───────────────────────────────────────────────────

  Future<Household?> getHousehold(String householdId) async {
    final doc =
        await _db.collection('households').doc(householdId).get();
    if (!doc.exists) return null;
    return Household.fromFirestore(doc);
  }

  Future<String> createHousehold(String name, String creatorId) async {
    final doc = await _db.collection('households').add({
      'name': name,
      'memberIds': [creatorId],
      'createdBy': creatorId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> joinHousehold(String householdId, String userId) async {
    await _db.collection('households').doc(householdId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> updateHouseholdId(String userId, String householdId) async {
    await _db.collection('users').doc(userId).update({
      'householdId': householdId,
    });
  }

  // ─── Sustainability Stats ────────────────────────────────────────

  CollectionReference _statsRef(String householdId) =>
      _db.collection('households').doc(householdId).collection('stats');

  Future<Map<String, dynamic>> getStats(String householdId) async {
    final doc = await _statsRef(householdId).doc('summary').get();
    if (!doc.exists) {
      return {
        'mealsCooked': 0,
        'foodSavedKg': 0.0,
        'moneySaved': 0.0,
        'co2AvoidedKg': 0.0,
        'fwrs': 0,
      };
    }
    return doc.data() as Map<String, dynamic>;
  }

  Future<void> updateStats(
      String householdId, Map<String, dynamic> data) async {
    await _statsRef(householdId).doc('summary').set(data, SetOptions(merge: true));
  }
}
