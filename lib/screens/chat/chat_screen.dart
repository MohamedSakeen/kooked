import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../services/api_service.dart';
import '../../services/firestore_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _api = ApiService();
  final _firestore = FirestoreService();
  bool _isTyping = false;
  bool _chefMode = false;
  bool _hasError = false;

  final List<ChatMessage> _messages = [
    ChatMessage.ai(
      'Hi! I\'m your Kitchen Assistant. I can help you discover recipes, '
      'manage your pantry, and cook with what you have. What would you like to do?',
    ),
  ];

  String get _householdId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'demo';

  Future<List<Map<String, dynamic>>> _getPantryContext() async {
    try {
      final items = await _firestore.getPantryItems(_householdId);
      return items
          .map((item) => {
                'name': item.name,
                'quantity': item.quantity,
                'unit': item.unit,
                'category': item.category,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage.user(text));
      _isTyping = true;
      _hasError = false;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final pantryContext = await _getPantryContext();
      final reply = await _api.chatWithAssistant(
        message: text,
        pantryContext: pantryContext,
        chefMode: _chefMode,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage.ai(reply));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage.ai(
            'Sorry, I couldn\'t process that request. Please check your connection and try again.',
          ));
          _isTyping = false;
          _hasError = true;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Assistant'),
        actions: [
          Row(
            children: [
              const Text('Chef Mode', style: TextStyle(fontSize: 12)),
              Switch(
                value: _chefMode,
                onChanged: (val) => setState(() => _chefMode = val),
                activeThumbColor: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.length == 1 && !_isTyping
                ? _buildWelcomeHints()
                : ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: _chefMode
                            ? 'Ask for next step...'
                            : 'Ask what to cook...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 18),
                      onPressed: _isTyping ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHints() {
    final hints = [
      {'icon': Icons.restaurant_menu, 'text': 'What can I cook today?'},
      {'icon': Icons.lightbulb_outline, 'text': 'Suggest a recipe'},
      {'icon': Icons.help_outline, 'text': 'How do I store tomatoes?'},
      {'icon': Icons.eco, 'text': 'Tips to reduce food waste'},
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _chefMode ? Icons.restaurant : Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _chefMode
                  ? 'Chef Mode active — ask me for cooking steps!'
                  : 'Ask me anything about cooking and your pantry',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hints.map((h) {
                return ActionChip(
                  avatar: Icon(h['icon'] as IconData,
                      size: 16, color: AppColors.primary),
                  label: Text(h['text'] as String,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _inputController.text = h['text'] as String;
                    _sendMessage();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          msg.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (_, value, _) {
        return Opacity(
          opacity: (value * 2).clamp(0.0, 1.0),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.textHint,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
