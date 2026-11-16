import 'package:flutter_test/flutter_test.dart';
import 'package:show_on_move/login_screen.dart';
import 'package:show_on_move/main.dart';

void main() {
  testWidgets('MyApp launches LoginScreen smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
