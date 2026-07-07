import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:samantha/app/app.dart';
import 'package:samantha/app/injection.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
  });
}
