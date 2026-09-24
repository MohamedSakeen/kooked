import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_preferences.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Request permission and get FCM token
  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        if (token != null) {
          await _saveToken(token);
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen(_saveToken);
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background tap
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check if app opened from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    } catch (e) {
      debugPrint('NotificationService initialization skipped/failed: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).update({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // In-app notification handling can be added here
    // For now, messages are received but not displayed as OS notifications in foreground
  }

  void _handleMessageTap(RemoteMessage message) {
    // Navigate based on notification data
    // final data = message.data;
    // Navigation will be handled by the router listener
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (_) {}
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (_) {}
  }

  /// Save notification preferences to Firestore
  Future<void> savePreferences(NotificationPreferences prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).update({
      'notificationPreferences': prefs.toMap(),
    });

    // Manage topic subscriptions based on preferences
    if (prefs.expiryAlerts) {
      await subscribeToTopic('expiry_alerts');
    } else {
      await unsubscribeFromTopic('expiry_alerts');
    }

    if (prefs.recipeSuggestions) {
      await subscribeToTopic('recipe_suggestions');
    } else {
      await unsubscribeFromTopic('recipe_suggestions');
    }

    if (prefs.shoppingReminders) {
      await subscribeToTopic('shopping_reminders');
    } else {
      await unsubscribeFromTopic('shopping_reminders');
    }

    if (prefs.wasteTips) {
      await subscribeToTopic('waste_tips');
    } else {
      await unsubscribeFromTopic('waste_tips');
    }
  }

  /// Load notification preferences from Firestore
  Future<NotificationPreferences> loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return NotificationPreferences.defaults();

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return NotificationPreferences.defaults();

    final data = doc.data();
    final prefs = data?['notificationPreferences'];
    if (prefs == null) return NotificationPreferences.defaults();

    return NotificationPreferences.fromMap(prefs);
  }
}

/// Top-level handler for background messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message handling
}

/// Register background handler
void registerBackgroundHandler() {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Background message registration skipped/failed: $e');
    }
  }
}
