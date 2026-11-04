import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:electrical_shop_manager/main.dart';

void main() {
  testWidgets('Owner can set up access before opening the shop', (
    WidgetTester tester,
  ) async {
    String? storedPin;
    await tester.pumpWidget(
      MaterialApp(
        home: OwnerAccessGate(
          readPin: () async => storedPin,
          writePin: (pin) async => storedPin = pin,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ELECTRICAL SHOP'), findsOneWidget);
    expect(find.text('Set up owner access'), findsOneWidget);
    expect(find.text('Create PIN and continue'), findsOneWidget);
  });
}
