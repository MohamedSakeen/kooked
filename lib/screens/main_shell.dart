import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    int currentIndex = 0;
    if (location.startsWith('/recipes')) currentIndex = 1;
    if (location.startsWith('/shopping')) currentIndex = 2;
    if (location.startsWith('/dashboard')) currentIndex = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/pantry');
            case 1:
              context.go('/recipes');
            case 2:
              context.go('/shopping');
            case 3:
              context.go('/dashboard');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen),
            activeIcon: Icon(Icons.kitchen),
            label: 'Pantry',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            activeIcon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chat'),
        tooltip: 'Kitchen Assistant',
        child: const Icon(Icons.chat),
      ),
    );
  }
}
