import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firesight_mobile/widgets/auth/first_login_password_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirstLoginPasswordDialog Widget & Validation Tests', () {
    testWidgets('renders security dialog header, instructions, inputs and buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FirstLoginPasswordDialog(),
          ),
        ),
      );

      // Verify title & security explanation
      expect(find.text('Set Your New Password'), findsOneWidget);
      expect(find.byIcon(Icons.lock_reset_rounded), findsOneWidget);
      expect(
        find.textContaining('Your account was created by a Station Officer with a temporary password.'),
        findsOneWidget,
      );

      // Verify inputs and action buttons
      expect(find.widgetWithText(TextFormField, 'New Password'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirm New Password'), findsOneWidget);
      expect(find.text('Set New Password & Continue'), findsOneWidget);
      expect(find.text('Cancel & Sign Out'), findsOneWidget);
    });

    testWidgets('rejects passwords shorter than 8 characters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FirstLoginPasswordDialog(),
          ),
        ),
      );

      // Enter 6 characters
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'Pass1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'Pass1');

      await tester.tap(find.text('Set New Password & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters long'), findsOneWidget);
    });

    testWidgets('rejects passwords without numbers or letters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FirstLoginPasswordDialog(),
          ),
        ),
      );

      // Letters only
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'AllLettersNoNumber');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'AllLettersNoNumber');

      await tester.tap(find.text('Set New Password & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Must include at least one letter and one number'), findsOneWidget);

      // Numbers only
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), '1234567890');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), '1234567890');

      await tester.tap(find.text('Set New Password & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Must include at least one letter and one number'), findsOneWidget);
    });

    testWidgets('rejects mismatched confirm password', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FirstLoginPasswordDialog(),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'SecurePass123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'DifferentPass456');

      await tester.tap(find.text('Set New Password & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
