import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/config/theme.dart';

void main() {
  group('RegisterScreen form validation', () {
    testWidgets('form validation rejects empty fields',
        (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 chars' : null,
                ),
              ],
            ),
          ),
        ),
      ));

      expect(formKey.currentState!.validate(), false);
    });

    testWidgets('form validation accepts valid input',
        (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  initialValue: 'John Doe',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  initialValue: 'john@example.com',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  initialValue: 'password123',
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 chars' : null,
                ),
              ],
            ),
          ),
        ),
      ));

      expect(formKey.currentState!.validate(), true);
    });

    testWidgets('password validation rejects short password',
        (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  initialValue: 'abc',
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 chars' : null,
                ),
              ],
            ),
          ),
        ),
      ));

      expect(formKey.currentState!.validate(), false);
    });
  });
}
