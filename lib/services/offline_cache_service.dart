import 'dart:convert';
import 'package:hive_ce/hive.dart';
import '../models/pantry_item.dart';

class OfflineCacheService {
  static const String _pantryBox = 'pantry_cache';
  static const String _syncQueueBox = 'sync_queue';
  late Box<String> _pantryCache;
  late Box<String> _syncQueue;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    _pantryCache = await Hive.openBox<String>(_pantryBox);
    _syncQueue = await Hive.openBox<String>(_syncQueueBox);
    _isInitialized = true;
  }

  // ─── Pantry Cache ────────────────────────────────────────────────

  Future<void> cachePantry(String householdId, List<PantryItem> items) async {
    if (!_isInitialized) await init();
    final jsonList = items.map((item) {
      return jsonEncode({
        'id': item.id,
        'name': item.name,
        'category': item.category,
        'quantity': item.quantity,
        'unit': item.unit,
        'type': item.type,
        'dateAdded': item.dateAdded.toIso8601String(),
        'imageUrl': item.imageUrl,
        'addedBy': item.addedBy,
        'householdId': item.householdId,
      });
    }).toList();
    await _pantryCache.put(householdId, jsonEncode(jsonList));
  }

  List<PantryItem> getCachedPantry(String householdId) {
    if (!_isInitialized) return [];
    final raw = _pantryCache.get(householdId);
    if (raw == null) return [];

    final List<dynamic> jsonList = jsonDecode(raw);
    return jsonList.map((e) {
      final map = jsonDecode(e.toString()) as Map<String, dynamic>;
      return PantryItem(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        category: map['category'] ?? 'Other',
        quantity: (map['quantity'] ?? 0).toDouble(),
        unit: map['unit'] ?? 'pcs',
        type: map['type'] ?? 'Raw',
        dateAdded: DateTime.parse(map['dateAdded']),
        imageUrl: map['imageUrl'],
        addedBy: map['addedBy'] ?? '',
        householdId: map['householdId'] ?? '',
      );
    }).toList();
  }

  bool hasCache(String householdId) {
    if (!_isInitialized) return false;
    return _pantryCache.containsKey(householdId);
  }

  // ─── Sync Queue ──────────────────────────────────────────────────

  Future<void> queueOperation(Map<String, dynamic> operation) async {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await _syncQueue.put(key, jsonEncode(operation));
  }

  List<Map<String, dynamic>> getPendingOperations() {
    return _syncQueue.values.map((e) {
      return jsonDecode(e) as Map<String, dynamic>;
    }).toList();
  }

  Future<void> clearSyncQueue() async {
    await _syncQueue.clear();
  }

  Future<void> removeOperation(String key) async {
    await _syncQueue.delete(key);
  }

  List<String> get pendingKeys => _syncQueue.keys.cast<String>().toList();
}
