import 'package:flutter_test/flutter_test.dart';
import 'package:poker_tracker/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const PokerTrackerApp());
    expect(find.text('Start Cash Game'), findsOneWidget);
  });
}
