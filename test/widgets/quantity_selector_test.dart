import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/widgets/quantity_selector.dart';
import 'package:kooked/config/theme.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  group('QuantitySelector', () {
    testWidgets('displays initial quantity and unit',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        QuantitySelector(
          quantity: 3,
          unit: 'pcs',
          onChanged: (_) {},
        ),
      ));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('pcs'), findsOneWidget);
    });

    testWidgets('displays fractional quantity correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        QuantitySelector(
          quantity: 2.5,
          unit: 'kg',
          onChanged: (_) {},
        ),
      ));

      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('add button increments quantity', (WidgetTester tester) async {
      double currentQty = 3;

      await tester.pumpWidget(wrapInApp(
        QuantitySelector(
          quantity: currentQty,
          unit: 'pcs',
          onChanged: (val) => currentQty = val,
          step: 1,
        ),
      ));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(currentQty, 4.0);
    });

    testWidgets('remove button decrements quantity',
        (WidgetTester tester) async {
      double currentQty = 3;

      await tester.pumpWidget(wrapInApp(
        QuantitySelector(
          quantity: currentQty,
          unit: 'pcs',
          onChanged: (val) => currentQty = val,
          step: 1,
        ),
      ));

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(currentQty, 2.0);
    });

    testWidgets('does not go below min', (WidgetTester tester) async {
      double currentQty = 1;

      await tester.pumpWidget(wrapInApp(
        QuantitySelector(
          quantity: currentQty,
          unit: 'pcs',
          onChanged: (val) => currentQty = val,
          step: 1,
          min: 1,
        ),
      ));

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(currentQty, 1.0); // unchanged
    });

    testWidgets('does not go above max', (WidgetTester tester) async {
      double currentQty = 999;

      await tester.pumpWidget(wrapInApp(
        QuantitySelector(
          quantity: currentQty,
          unit: 'pcs',
          onChanged: (val) => currentQty = val,
          step: 1,
          max: 999,
        ),
      ));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(currentQty, 999.0); // unchanged
    });

    testWidgets('respects step size of 0.5',
        (WidgetTester tester) async {
      double currentQty = 1.0;

      await tester.pumpWidget(wrapInApp(
        QuantitySelector(
          quantity: currentQty,
          unit: 'kg',
          onChanged: (val) => currentQty = val,
          step: 0.5,
        ),
      ));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(currentQty, 1.5);
    });
  });
}
