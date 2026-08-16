import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';
import '../../models/shopping_item.dart';
import '../../widgets/empty_state.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _addController = TextEditingController();
  final _firestore = FirestoreService();
  bool _isLoading = false;

  String get _householdId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'demo';
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final item = ShoppingItem(
        id: '',
        name: text,
        quantity: 1,
        unit: 'pcs',
        isChecked: false,
        householdId: _householdId,
      );
      await _firestore.addShoppingItem(_householdId, item);
      _addController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleItem(ShoppingItem item) async {
    try {
      await _firestore.updateShoppingItem(
        _householdId,
        item.id,
        {'isChecked': !item.isChecked},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    try {
      await _firestore.deleteShoppingItem(_householdId, item.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: StreamBuilder<List<ShoppingItem>>(
        stream: _firestore.shoppingStream(_householdId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Shopping list is empty',
              subtitle: 'Add items manually or from a recipe\'s missing ingredients',
            );
          }

          final unchecked = items.where((i) => !i.isChecked).toList();
          final checked = items.where((i) => i.isChecked).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              if (unchecked.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('To Buy (${unchecked.length})',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                ...unchecked.map((item) => _buildItemTile(item)),
              ],
              if (checked.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Got It (${checked.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textHint,
                          )),
                ),
                ...checked.map((item) => _buildItemTile(item)),
              ],
            ],
          );
        },
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  decoration: const InputDecoration(
                    hintText: 'Add item...',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 44,
                width: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _addItem,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(ShoppingItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(item),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => _toggleItem(item),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: item.isChecked ? AppColors.primary : AppColors.divider,
                width: 2,
              ),
              color: item.isChecked ? AppColors.primary : Colors.transparent,
            ),
            child: item.isChecked
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? AppColors.textHint : AppColors.textPrimary,
          ),
        ),
        subtitle: item.unit.isNotEmpty
            ? Text('${item.quantity} ${item.unit}',
                style: TextStyle(
                  fontSize: 12,
                  color: item.isChecked
                      ? AppColors.textHint
                      : AppColors.textSecondary,
                ))
            : null,
      ),
    );
  }
}
