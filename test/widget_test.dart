import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kickoff/screens/auth_screen.dart';

void main() {
  testWidgets('Auth screen shows login and demo accounts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    expect(find.text('Kickoff'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.textContaining('mantoman'), findsOneWidget);
  });
}
