import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../utils/constants.dart';
import '../../services/firestore_service.dart';
import '../../services/offline_cache_service.dart';
import '../../models/pantry_item.dart';
import '../../widgets/pantry_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_retry_widget.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final _firestore = FirestoreService();
  final _cache = OfflineCacheService();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  String get _householdId {
    final user = FirebaseAuth.instance.currentUser;
    // TODO: Replace with actual householdId from user profile
    return user?.uid ?? 'demo';
  }

  @override
  void initState() {
    super.initState();
    _cache.init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PantryItem> _filterItems(List<PantryItem> items) {
    return items.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...AppConstants.pantryCategories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pantry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => context.push('/scan'),
            tooltip: 'Scan items',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/notifications'),
            tooltip: 'Notification settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search pantry...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final selected = cat == _selectedCategory;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat),
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<PantryItem>>(
              stream: _firestore.pantryStream(_householdId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Show cached data while loading
                  if (_cache.hasCache(_householdId)) {
                    final cached = _cache.getCachedPantry(_householdId);
                    return _buildList(cached);
                  }
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (snapshot.hasError) {
                  // Fall back to cache on error
                  if (_cache.hasCache(_householdId)) {
                    final cached = _cache.getCachedPantry(_householdId);
                    return _buildList(cached);
                  }
                  return ErrorRetryWidget(
                    title: 'Failed to load pantry',
                    message: 'Check your connection and try again',
                    onRetry: () => setState(() {}),
                  );
                }

                final items = snapshot.data ?? [];

                // Cache for offline use
                if (items.isNotEmpty) {
                  _cache.cachePantry(_householdId, items);
                }

                return _buildList(items);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<PantryItem> allItems) {
    final items = _filterItems(allItems);

    if (allItems.isEmpty) {
      return EmptyState(
        icon: Icons.kitchen,
        title: 'Your pantry is empty',
        subtitle: 'Add items manually or scan a receipt to get started',
        actionLabel: 'Add Item',
        onAction: () => context.push('/add-item'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('${items.length} items',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'No items match "${_searchQuery.isNotEmpty ? _searchQuery : _selectedCategory}"',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return PantryCard(
                      name: item.name,
                      category: item.category,
                      quantity: item.quantity,
                      unit: item.unit,
                      type: item.type,
                      dateAdded: item.dateAdded,
                      imageUrl: item.imageUrl,
                      onTap: () =>
                          context.push('/edit-item/${item.id}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
