import 'package:flutter_test/flutter_test.dart';

import 'package:samantha/app/app.dart';
import 'package:samantha/app/injection.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await configureDependencies();
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
  });
}
