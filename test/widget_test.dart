// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie_delivery/screens/food_detail_screen.dart';

void main() {
  testWidgets('FoodDetailScreen renders cleanly on mobile viewport without blank/overflow errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FoodDetailScreen(
          title: 'Milano Truffle Crust Pizza Super Deluxe',
          basePrice: 12.99,
          description: 'Delicious pizza with extra truffle and creamy cheese.',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Detail Menu'), findsOneWidget);
    expect(find.text('Milano Truffle Crust Pizza Super Deluxe'), findsOneWidget);
    expect(find.byType(FoodDetailScreen), findsOneWidget);
  });
}
