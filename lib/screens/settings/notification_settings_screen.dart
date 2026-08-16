import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/notification_preferences.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationService _service = NotificationService();
  NotificationPreferences? _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _service.loadPreferences();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePreference({
    bool? expiryAlerts,
    bool? recipeSuggestions,
    bool? shoppingReminders,
    bool? wasteTips,
    bool? cookingReminders,
  }) async {
    if (_prefs == null) return;

    final updated = _prefs!.copyWith(
      expiryAlerts: expiryAlerts,
      recipeSuggestions: recipeSuggestions,
      shoppingReminders: shoppingReminders,
      wasteTips: wasteTips,
      cookingReminders: cookingReminders,
    );

    setState(() => _prefs = updated);
    await _service.savePreferences(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferences saved'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _prefs == null
              ? const Center(child: Text('Failed to load preferences'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 20),
                    _buildSection('Reminders', [
                      _buildSwitch(
                        icon: Icons.access_alarm,
                        title: 'Cooking Reminders',
                        subtitle: 'Remind you to cook items before they expire',
                        value: _prefs!.cookingReminders,
                        onChanged: (v) =>
                            _updatePreference(cookingReminders: v),
                      ),
                      _buildSwitch(
                        icon: Icons.shopping_cart,
                        title: 'Shopping Reminders',
                        subtitle: 'Remind you to buy items from your list',
                        value: _prefs!.shoppingReminders,
                        onChanged: (v) =>
                            _updatePreference(shoppingReminders: v),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('AI Suggestions', [
                      _buildSwitch(
                        icon: Icons.restaurant_menu,
                        title: 'Recipe Suggestions',
                        subtitle: 'AI suggests recipes based on your pantry',
                        value: _prefs!.recipeSuggestions,
                        onChanged: (v) =>
                            _updatePreference(recipeSuggestions: v),
                      ),
                      _buildSwitch(
                        icon: Icons.eco,
                        title: 'Waste Reduction Tips',
                        subtitle: 'Tips to reduce food waste',
                        value: _prefs!.wasteTips,
                        onChanged: (v) => _updatePreference(wasteTips: v),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Alerts', [
                      _buildSwitch(
                        icon: Icons.warning_amber,
                        title: 'Expiry Alerts',
                        subtitle:
                            'Get notified when items are about to expire',
                        value: _prefs!.expiryAlerts,
                        onChanged: (v) =>
                            _updatePreference(expiryAlerts: v),
                      ),
                    ]),
                  ],
                ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notifications help you reduce food waste by reminding you about items before they expire.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
