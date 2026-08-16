import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/widgets/error_retry_widget.dart';
import 'package:kooked/config/theme.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  group('ErrorRetryWidget', () {
    testWidgets('displays default title and retry button',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        ErrorRetryWidget(
          onRetry: () {},
        ),
      ));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays custom title and message',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        ErrorRetryWidget(
          title: 'Load Failed',
          message: 'Check your internet connection',
          onRetry: () {},
        ),
      ));

      expect(find.text('Load Failed'), findsOneWidget);
      expect(find.text('Check your internet connection'), findsOneWidget);
    });

    testWidgets('retry button triggers callback',
        (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(wrapInApp(
        ErrorRetryWidget(
          title: 'Error',
          onRetry: () => retried = true,
        ),
      ));

      await tester.tap(find.text('Try Again'));
      expect(retried, true);
    });

    testWidgets('hides message when not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapInApp(
        ErrorRetryWidget(
          title: 'Error Only',
          onRetry: () {},
        ),
      ));

      expect(find.text('Error Only'), findsOneWidget);
      // Should not have message text
      expect(find.byType(Text), findsNWidgets(2)); // title + button text
    });
  });
}
