import 'package:flutter_test/flutter_test.dart';

import 'package:samantha/main.dart';

void main() {
  testWidgets('App shows welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SamanthaApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Saman\u{1E6D}ha'), findsOneWidget);
  });
}
