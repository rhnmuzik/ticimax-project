import 'package:flutter_test/flutter_test.dart';
import 'package:ticimax_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TicimaxApp());
    expect(find.text('Ticimax'), findsOneWidget);
  });
}
