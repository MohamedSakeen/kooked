import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/widgets/confirm_dialog.dart';
import 'package:kooked/config/theme.dart';

void main() {
  group('ConfirmDialog', () {
    testWidgets('displays title and content', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ConfirmDialog(
                  title: 'Delete Item?',
                  content: 'This action cannot be undone.',
                  onConfirm: () {},
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Item?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);
    });

    testWidgets('confirm button triggers callback',
        (WidgetTester tester) async {
      bool confirmed = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ConfirmDialog(
                  title: 'Confirm',
                  content: 'Are you sure?',
                  confirmLabel: 'Yes',
                  onConfirm: () => confirmed = true,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(confirmed, true);
    });

    testWidgets('cancel button dismisses dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ConfirmDialog(
                  title: 'Confirm',
                  content: 'Content',
                  onConfirm: () {},
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('custom labels are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ConfirmDialog(
                  title: 'Title',
                  content: 'Content',
                  confirmLabel: 'Do It',
                  cancelLabel: 'Nope',
                  onConfirm: () {},
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Do It'), findsOneWidget);
      expect(find.text('Nope'), findsOneWidget);
    });
  });
}
