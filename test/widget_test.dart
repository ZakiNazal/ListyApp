import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listyapp/core/theme/app_colors.dart';
import 'package:listyapp/core/theme/app_theme.dart';
import 'package:listyapp/widgets/primary_button.dart';

/// The full app cannot be pumped in a plain widget test because `main()` calls
/// `Firebase.initializeApp`, which needs platform channels. These tests cover
/// the shared widgets instead; the Firebase-backed screens are better served by
/// an integration test against the emulator suite.
Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PrimaryButton', () {
    testWidgets('fires its callback when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(PrimaryButton(label: 'Send', onPressed: () => taps++)),
      );

      expect(find.text('Send'), findsOneWidget);

      await tester.tap(find.text('Send'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('renders grey and ignores taps when disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrimaryButton(label: 'Send')),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.color, AppColors.disabled);

      // Tapping must not throw and must not do anything.
      await tester.tap(find.text('Send'));
      await tester.pump();
    });

    testWidgets('shows a spinner and blocks taps while loading',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(
            label: 'Send',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Send'), findsNothing);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(taps, 0);
    });
  });
}
