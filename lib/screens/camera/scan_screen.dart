import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/firestore_service.dart';
import '../../models/pantry_item.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_retry_widget.dart';

import '../../services/food_classification_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _api = ApiService();
  final FirestoreService _firestore = FirestoreService();
  final FoodClassificationService _classifier = FoodClassificationService();
  XFile? _capturedImage;
  bool _isAnalyzing = false;
  bool _showResults = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _detectedItems = [];

  String get _householdId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'demo';

  Future<void> _captureImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      _capturedImage = image;
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final file = File(image.path);
      final result = await _api.visionAnalysis(file);

      final rawItems = result['items'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> items = [];

      for (final item in rawItems) {
        final rawName = item['name'] ?? '';
        final classResult = await _classifier.classify(rawName);

        items.add({
          'name': classResult.canonicalName.isNotEmpty ? classResult.canonicalName : rawName,
          'qty': (item['quantity'] ?? 1).toDouble(),
          'unit': item['unit'] ?? 'pcs',
          'category': classResult.category,
          'type': classResult.type,
          'confirmed': false,
        });
      }

      if (mounted) {
        setState(() {
          _detectedItems = items;
          _isAnalyzing = false;
          _showResults = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Failed to analyze image: ${e.toString()}';
        });
      }
    }
  }

  void _toggleConfirm(int index) {
    setState(() {
      _detectedItems[index]['confirmed'] =
          !_detectedItems[index]['confirmed'];
    });
  }

  void _updateQty(int index, double delta) {
    setState(() {
      final newQty = (_detectedItems[index]['qty'] + delta).clamp(0.5, 999);
      _detectedItems[index]['qty'] = newQty;
    });
  }

  Future<void> _confirmAll() async {
    final confirmed =
        _detectedItems.where((i) => i['confirmed'] == true).toList();

    if (confirmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final existingItems = await _firestore.getPantryItems(_householdId);

      for (final item in confirmed) {
        final duplicate = FoodClassificationService.findDuplicate(item['name'], existingItems);
        if (duplicate != null) {
          final newQty = duplicate.quantity + (item['qty'] as double);
          await _firestore.updatePantryItem(
            _householdId,
            duplicate.id,
            {'quantity': newQty},
          );
        } else {
          final pantryItem = PantryItem(
            id: '',
            name: item['name'],
            category: item['category'],
            quantity: item['qty'].toDouble(),
            unit: item['unit'],
            type: item['type'] ?? 'Raw',
            dateAdded: DateTime.now(),
            addedBy: user?.uid ?? '',
            householdId: _householdId,
          );
          await _firestore.addPantryItem(_householdId, pantryItem);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${confirmed.length} items added to pantry'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add items: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _showResults = false;
      _isAnalyzing = false;
      _errorMessage = null;
      _detectedItems = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Items'),
        actions: [
          if (_showResults)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Scan again',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            ErrorRetryWidget(
              title: 'Scan Failed',
              message: _errorMessage,
              onRetry: _reset,
            )
          else if (!_showResults && _capturedImage == null)
            _buildCameraView()
          else if (_capturedImage != null && !_showResults)
            _buildPreview()
          else if (_showResults)
            _buildResults(),
          if (_isAnalyzing)
            const LoadingOverlay(message: 'AI is analyzing your image...'),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Capture your ingredients',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI will identify food items and estimate quantities',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _captureImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _captureImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Center(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_capturedImage!.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final selectedCount =
        _detectedItems.where((i) => i['confirmed'] == true).length;

    return Column(
      children: [
        if (_capturedImage != null)
          Container(
            height: 140,
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.cover,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                '${_detectedItems.length} items detected',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    for (var item in _detectedItems) {
                      item['confirmed'] = true;
                    }
                  });
                },
                child: const Text('Select All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _detectedItems.length,
            itemBuilder: (context, index) {
              final item = _detectedItems[index];
              final confirmed = item['confirmed'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _toggleConfirm(index),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: confirmed
                                ? AppColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: confirmed
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: 2,
                            ),
                          ),
                          child: confirmed
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(item['category'],
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildMiniButton(
                                Icons.remove, () => _updateQty(index, -0.5)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item['qty']} ${item['unit']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            _buildMiniButton(
                                Icons.add, () => _updateQty(index, 0.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedCount > 0 ? _confirmAll : null,
                child: Text(
                  'Add $selectedCount Items to Pantry',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 14, color: AppColors.textPrimary),
      ),
    );
  }
}
