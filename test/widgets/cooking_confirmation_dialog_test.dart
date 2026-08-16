import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/widgets/cooking_confirmation_dialog.dart';
import 'package:kooked/models/cooking_history.dart';
import 'package:kooked/config/theme.dart';

CookedIngredient _makeIngredient(String name, double qty, String unit,
    {String? pantryItemId}) {
  return CookedIngredient(
    name: name,
    quantityConsumed: qty,
    unit: unit,
    pantryItemId: pantryItemId,
  );
}

void main() {
  group('CookingConfirmationDialog', () {
    testWidgets('displays recipe title, servings, and ingredients',
        (WidgetTester tester) async {
      final ingredients = [
        _makeIngredient('Pasta', 200, 'g', pantryItemId: 'p1'),
        _makeIngredient('Tomato Sauce', 100, 'ml', pantryItemId: 'p2'),
      ];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CookingConfirmationDialog(
                  recipeTitle: 'Pasta Pomodoro',
                  servings: 2,
                  ingredients: ingredients,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Consumption'), findsOneWidget);
      expect(find.textContaining('Pasta Pomodoro'), findsWidgets);
      expect(find.textContaining('2 serving'), findsWidgets);
      expect(find.text('Pasta'), findsWidgets);
      expect(find.text('Tomato Sauce'), findsWidgets);
    });

    testWidgets('plus button increments quantity by 0.5',
        (WidgetTester tester) async {
      final ingredients = [
        _makeIngredient('Pasta', 200, 'g', pantryItemId: 'p1'),
      ];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CookingConfirmationDialog(
                  recipeTitle: 'Test',
                  servings: 1,
                  ingredients: ingredients,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap add button for first ingredient
      final addButtons = find.byIcon(Icons.add);
      expect(addButtons, findsOneWidget);

      await tester.tap(addButtons.first);
      await tester.pump();

      expect(ingredients.first.quantityConsumed, 200.5);
    });

    testWidgets('minus button decrements quantity by 0.5',
        (WidgetTester tester) async {
      final ingredients = [
        _makeIngredient('Pasta', 200, 'g', pantryItemId: 'p1'),
      ];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CookingConfirmationDialog(
                  recipeTitle: 'Test',
                  servings: 1,
                  ingredients: ingredients,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(ingredients.first.quantityConsumed, 199.5);
    });

    testWidgets('quantity does not go below zero',
        (WidgetTester tester) async {
      final ingredients = [
        _makeIngredient('Spice', 0.5, 'tsp', pantryItemId: 'p1'),
      ];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CookingConfirmationDialog(
                  recipeTitle: 'Test',
                  servings: 1,
                  ingredients: ingredients,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(ingredients.first.quantityConsumed, 0);
    });

    testWidgets('Confirm & Update Pantry returns edited ingredients via pop',
        (WidgetTester tester) async {
      final ingredients = [
        _makeIngredient('Eggs', 2, 'pcs', pantryItemId: 'p1'),
      ];

      List<CookedIngredient>? result;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog(
                  context: context,
                  builder: (_) => CookingConfirmationDialog(
                    recipeTitle: 'Omelette',
                    servings: 1,
                    ingredients: ingredients,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Confirm button exists
      expect(find.text('Confirm & Update Pantry'), findsOneWidget);

      await tester.tap(find.text('Confirm & Update Pantry'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result!.first.name, 'Eggs');
    });

    testWidgets('Cancel dismisses without returning',
        (WidgetTester tester) async {
      final ingredients = [
        _makeIngredient('Item', 1, 'pcs', pantryItemId: 'p1'),
      ];

      List<CookedIngredient>? result;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog(
                  context: context,
                  builder: (_) => CookingConfirmationDialog(
                    recipeTitle: 'Test',
                    servings: 1,
                    ingredients: ingredients,
                    onCancel: () {},
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Result should be null (dialog dismissed, not confirmed)
      expect(result, isNull);
    });

    testWidgets('shows check_circle for in-pantry items',
        (WidgetTester tester) async {
      final ingredients = [
        _makeIngredient('Available', 1, 'pcs', pantryItemId: 'p1'),
        _makeIngredient('Missing', 1, 'pcs'),
      ];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CookingConfirmationDialog(
                  recipeTitle: 'Test',
                  servings: 1,
                  ingredients: ingredients,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should display both ingredient names
      expect(find.text('Available'), findsWidgets);
      expect(find.text('Missing'), findsWidgets);

      // In-pantry item gets check_circle, missing gets help_outline
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('shows singular serving text for 1',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CookingConfirmationDialog(
                  recipeTitle: 'Single',
                  servings: 1,
                  ingredients: [],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 serving'), findsWidgets);
      expect(find.textContaining('1 servings'), findsNothing);
    });
  });
}
