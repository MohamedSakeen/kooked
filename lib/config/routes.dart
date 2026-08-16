import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main_shell.dart';
import '../screens/pantry/pantry_screen.dart';
import '../screens/pantry/add_item_screen.dart';
import '../screens/recipes/recipes_screen.dart';
import '../screens/recipes/recipe_detail_screen.dart';
import '../screens/shopping/shopping_list_screen.dart';
import '../screens/dashboard/sustainability_screen.dart';
import '../screens/camera/scan_screen.dart';
import '../screens/camera/bill_scan_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import 'page_transitions.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final isAuthRoute =
        state.matchedLocation == '/login' || state.matchedLocation == '/register';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/pantry';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const RegisterScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideTween =
              Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(
            position: slideTween,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/pantry',
          builder: (context, state) => const PantryScreen(),
        ),
        GoRoute(
          path: '/recipes',
          builder: (context, state) => const RecipesScreen(),
        ),
        GoRoute(
          path: '/shopping',
          builder: (context, state) => const ShoppingListScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const SustainabilityScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/add-item',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AddItemScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return slideFadeTransition(context, animation, secondaryAnimation, child);
        },
      ),
    ),
    GoRoute(
      path: '/edit-item/:id',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: AddItemScreen(editItemId: state.pathParameters['id']),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return slideFadeTransition(context, animation, secondaryAnimation, child);
        },
      ),
    ),
    GoRoute(
      path: '/recipe/:id',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: RecipeDetailScreen(recipeId: state.pathParameters['id']!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return slideFadeTransition(context, animation, secondaryAnimation, child);
        },
      ),
    ),
    GoRoute(
      path: '/scan',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ScanScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return slideFadeTransition(context, animation, secondaryAnimation, child);
        },
      ),
    ),
    GoRoute(
      path: '/bill-scan',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const BillScanScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return slideFadeTransition(context, animation, secondaryAnimation, child);
        },
      ),
    ),
    GoRoute(
      path: '/chat',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ChatScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideTween =
              Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(
            position: slideTween,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const NotificationSettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return slideFadeTransition(context, animation, secondaryAnimation, child);
        },
      ),
    ),
  ],
);
