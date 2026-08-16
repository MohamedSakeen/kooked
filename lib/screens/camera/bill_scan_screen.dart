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

class BillScanScreen extends StatefulWidget {
  const BillScanScreen({super.key});

  @override
  State<BillScanScreen> createState() => _BillScanScreenState();
}

class _BillScanScreenState extends State<BillScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _api = ApiService();
  final FirestoreService _firestore = FirestoreService();
  XFile? _capturedImage;
  bool _isAnalyzing = false;
  bool _showResults = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _extractedItems = [];

  String get _householdId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'demo';

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      _capturedImage = image;
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final file = File(image.path);
      final result = await _api.billOcrScan(file);

      final items = (result['items'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((item) {
        return {
          'name': item['name'] ?? '',
          'qty': (item['quantity'] ?? 1).toDouble(),
          'unit': item['unit'] ?? 'pcs',
          'status': 'new',
          'existingQty': 0.0,
          'confirmed': true,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _extractedItems = items;
          _isAnalyzing = false;
          _showResults = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Failed to read receipt: ${e.toString()}';
        });
      }
    }
  }

  void _toggleConfirm(int index) {
    setState(() {
      _extractedItems[index]['confirmed'] =
          !_extractedItems[index]['confirmed'];
    });
  }

  void _updateQty(int index, double delta) {
    setState(() {
      final newQty = (_extractedItems[index]['qty'] + delta).clamp(0.5, 999);
      _extractedItems[index]['qty'] = newQty;
    });
  }

  Future<void> _confirmAll() async {
    final confirmed =
        _extractedItems.where((i) => i['confirmed'] == true).toList();

    if (confirmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      for (final item in confirmed) {
        final pantryItem = PantryItem(
          id: '',
          name: item['name'],
          category: 'Other',
          quantity: item['qty'].toDouble(),
          unit: item['unit'],
          type: 'Packaged',
          dateAdded: DateTime.now(),
          addedBy: user?.uid ?? '',
          householdId: _householdId,
        );
        await _firestore.addPantryItem(_householdId, pantryItem);
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
      _extractedItems = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Bill'),
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
            _buildUploadView()
          else if (_showResults)
            _buildResults(),
          if (_isAnalyzing)
            const LoadingOverlay(message: 'AI is reading your receipt...'),
        ],
      ),
    );
  }

  Widget _buildUploadView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 50,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scan your grocery bill',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI will extract items and compare with your pantry',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final newItems =
        _extractedItems.where((i) => i['status'] == 'new').length;
    final selectedCount =
        _extractedItems.where((i) => i['confirmed'] == true).length;

    return Column(
      children: [
        if (_capturedImage != null)
          Container(
            height: 120,
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Text(
                '${_extractedItems.length} items found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (newItems > 0) _buildBadge('$newItems new', AppColors.primary),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _extractedItems.length,
            itemBuilder: (context, index) {
              final item = _extractedItems[index];
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
                              const SizedBox(height: 2),
                              const Text('New item',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary)),
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
                child: Text('Add $selectedCount Items to Pantry'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
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
