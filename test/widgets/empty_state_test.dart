import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/widgets/empty_state.dart';
import 'package:kooked/config/theme.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('displays icon, title, and subtitle',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        const EmptyState(
          icon: Icons.kitchen,
          title: 'Your pantry is empty',
          subtitle: 'Add items to get started',
        ),
      ));

      expect(find.byIcon(Icons.kitchen), findsOneWidget);
      expect(find.text('Your pantry is empty'), findsOneWidget);
      expect(find.text('Add items to get started'), findsOneWidget);
    });

    testWidgets('displays action button when provided',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(wrapInApp(
        EmptyState(
          icon: Icons.kitchen,
          title: 'Empty',
          subtitle: 'Subtitle',
          actionLabel: 'Add Item',
          onAction: () => tapped = true,
        ),
      ));

      expect(find.text('Add Item'), findsOneWidget);
      await tester.tap(find.text('Add Item'));
      expect(tapped, true);
    });

    testWidgets('hides action button when not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        const EmptyState(
          icon: Icons.kitchen,
          title: 'Empty',
          subtitle: 'Subtitle',
        ),
      ));

      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
