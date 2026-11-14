import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie_delivery/models/order_state.dart';
import 'package:foodie_delivery/screens/cart_screen.dart';
import 'package:foodie_delivery/widgets/coupon_applied_overlay.dart';

void main() {
  testWidgets('CouponAppliedOverlay renders cleanly with voucher details', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CouponAppliedOverlay(
          voucherCode: 'SUPER50',
          discountPercent: 0.50,
          discountAmount: 11.23,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Kupon Berhasil Dipakai!'), findsOneWidget);
    expect(find.textContaining('SUPER50'), findsOneWidget);
    expect(find.textContaining('Hemat 50%'), findsOneWidget);
  });

  testWidgets('CartScreen displays Pengantaran Cepat and Pengantaran Hemat with toggle support', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final orderState = OrderState.instance;
    orderState.clearCart();
    orderState.addSampleItems();
    orderState.toggleDelivery(true);

    await tester.pumpWidget(
      const MaterialApp(
        home: CartScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Verify both Pengantaran options are visible
    expect(find.text('Pengantaran Cepat'), findsWidgets);
    expect(find.text('Pengantaran Hemat'), findsWidgets);

    // Switch to Pengantaran Hemat
    final hematFinder = find.text('Pengantaran Hemat').first;
    await tester.tap(hematFinder);
    await tester.pump(const Duration(milliseconds: 300));

    expect(orderState.isFastDelivery, isFalse);

    // Switch back to Pengantaran Cepat
    final cepatFinder = find.text('Pengantaran Cepat').first;
    await tester.tap(cepatFinder);
    await tester.pump(const Duration(milliseconds: 300));

    expect(orderState.isFastDelivery, isTrue);

    // Drain CapsuleToast timer
    await tester.pump(const Duration(seconds: 6));
  });
}
