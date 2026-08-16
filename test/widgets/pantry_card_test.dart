import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/widgets/pantry_card.dart';
import 'package:kooked/config/theme.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  group('PantryCard', () {
    testWidgets('displays item name and category',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        PantryCard(
          name: 'Tomatoes',
          category: 'Produce',
          quantity: 3.0,
          unit: 'pcs',
          type: 'Raw',
          dateAdded: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ));

      expect(find.text('Tomatoes'), findsOneWidget);
      expect(find.textContaining('Produce'), findsOneWidget);
    });

    testWidgets('displays quantity and unit', (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        PantryCard(
          name: 'Milk',
          category: 'Dairy',
          quantity: 1.5,
          unit: 'L',
          type: 'Packaged',
          dateAdded: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ));

      expect(find.text('1.5 L'), findsOneWidget);
    });

    testWidgets('displays integer quantity without decimal',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        PantryCard(
          name: 'Eggs',
          category: 'Dairy',
          quantity: 12.0,
          unit: 'pcs',
          type: 'Packaged',
          dateAdded: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ));

      expect(find.text('12 pcs'), findsOneWidget);
    });

    testWidgets('displays type badge', (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        PantryCard(
          name: 'Leftover Curry',
          category: 'Leftovers',
          quantity: 1.0,
          unit: 'pcs',
          type: 'Leftover',
          dateAdded: DateTime.now(),
        ),
      ));

      expect(find.text('Leftover'), findsWidgets);
    });

    testWidgets('shows "Today" for items added today',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        PantryCard(
          name: 'Fresh Item',
          category: 'Produce',
          quantity: 1.0,
          unit: 'pcs',
          type: 'Raw',
          dateAdded: DateTime.now(),
        ),
      ));

      expect(find.textContaining('Today'), findsOneWidget);
    });

    testWidgets('shows "Yesterday" for items added yesterday',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        PantryCard(
          name: 'Old Item',
          category: 'Produce',
          quantity: 1.0,
          unit: 'pcs',
          type: 'Raw',
          dateAdded: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ));

      expect(find.textContaining('Yesterday'), findsOneWidget);
    });

    testWidgets('onTap is called when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(wrapInApp(
        PantryCard(
          name: 'Clickable',
          category: 'Produce',
          quantity: 1.0,
          unit: 'pcs',
          type: 'Raw',
          dateAdded: DateTime.now(),
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Clickable'));
      expect(tapped, true);
    });
  });
}
