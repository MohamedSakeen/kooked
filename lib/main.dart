import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'services/notification_service.dart' as notif;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  notif.registerBackgroundHandler();
  runApp(const KookedApp());
}

class KookedApp extends StatefulWidget {
  const KookedApp({super.key});

  @override
  State<KookedApp> createState() => _KookedAppState();
}

class _KookedAppState extends State<KookedApp> {
  @override
  void initState() {
    super.initState();
    notif.NotificationService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KooKed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: goRouter,
    );
  }
}
