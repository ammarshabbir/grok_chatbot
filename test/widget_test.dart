import 'package:flutter_test/flutter_test.dart';
import 'package:grokchatbot/main.dart';

void main() {
  testWidgets('app loads', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MyApp), findsOneWidget);
  });
}
