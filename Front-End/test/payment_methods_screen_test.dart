import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tokokita/screens/payment_methods_screen.dart';

void main() {
  testWidgets('explains that payment methods are chosen at checkout', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PaymentMethodsScreen()));

    expect(
      find.textContaining(
        'Pilih cara pembayaran untuk setiap pesanan saat checkout',
      ),
      findsOneWidget,
    );
    expect(find.text('GoPay / QRIS'), findsNothing);
    expect(find.text('Visa dan Mastercard'), findsNothing);
  });
}
