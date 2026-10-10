// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carwash_reservation/firebase_options.dart';
import 'package:carwash_reservation/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WashMate app loads its welcome screen', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await tester.pumpWidget(const WashMateApp());

    expect(find.text('WASH MATE'), findsOneWidget);
    expect(find.text('Premium care for your ride, without the stress.'),
        findsOneWidget);
  });
}
