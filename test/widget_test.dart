import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickle_manager/main.dart';

void main() {
  // Test group for the Pickleball Scoreboard App
  group('Pickleball Scoreboard', () {
    // Test to verify the initial state of the scoreboard
    testWidgets('should display initial scores of 0-0', (WidgetTester tester) async {
      // Build the app and trigger a frame.
      await tester.pumpWidget(const PickleballApp());

      // Find the score widgets for both teams.
      // Since the score '0' appears for both, we expect to find it twice.
      expect(find.text('0'), findsNWidgets(2));
    });

    // Test to verify score increment for the serving team
    testWidgets('should increment score for serving team on tap', (WidgetTester tester) async {
      // Build the app.
      await tester.pumpWidget(const PickleballApp());

      // Initially, Team A is serving. Tap on Team A's area.
      await tester.tap(find.text('Team A'));
      await tester.pump(); // Rebuild the widget after state change.

      // Verify that Team A's score is now 1.
      // We look for a Text widget with '1' inside a Column that also contains 'Team A'.
      expect(find.descendant(of: find.widgetWithText(Column, 'Team A'), matching: find.text('1')), findsOneWidget);
    });

    // Test to verify the "side out" logic
    testWidgets('should handle side out correctly', (WidgetTester tester) async {
      // Build the app.
      await tester.pumpWidget(const PickleballApp());

      // Initially, Team A is serving. Tap on Team B's area to cause a side out.
      await tester.tap(find.text('Team B'));
      await tester.pump(); // Rebuild the widget.

      // After a side out, the serve should switch to Team B.
      // We verify this by checking for the "SERVING" chip under Team B.
      expect(find.descendant(of: find.widgetWithText(Column, 'Team B'), matching: find.byType(Chip)), findsOneWidget);
      
      // Also, ensure Team A is no longer serving.
      expect(find.descendant(of: find.widgetWithText(Column, 'Team A'), matching: find.byType(Chip)), findsNothing);
    });

    // Test to verify the undo functionality
    testWidgets('should undo the last action', (WidgetTester tester) async {
      await tester.pumpWidget(const PickleballApp());

      // Score a point for Team A.
      await tester.tap(find.text('Team A'));
      await tester.pump();

      // Verify score is 1.
      expect(find.descendant(of: find.widgetWithText(Column, 'Team A'), matching: find.text('1')), findsOneWidget);

      // Tap the undo button.
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();

      // Verify the score is back to 0.
      expect(find.text('0'), findsNWidgets(2));
    });

    // Test to verify the reset functionality
    testWidgets('should reset the game', (WidgetTester tester) async {
      await tester.pumpWidget(const PickleballApp());

      // Score some points.
      await tester.tap(find.text('Team A'));
      await tester.pump();
      await tester.tap(find.text('Team A'));
      await tester.pump();

      // Verify score is 2.
      expect(find.descendant(of: find.widgetWithText(Column, 'Team A'), matching: find.text('2')), findsOneWidget);

      // Tap the reset button.
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Verify the score is back to 0 for both teams.
      expect(find.text('0'), findsNWidgets(2));
    });
  });
}