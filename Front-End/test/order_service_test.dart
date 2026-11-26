import 'package:flutter_test/flutter_test.dart';
import 'package:tokokita/services/order_service.dart';

void main() {
  group('OrderService payment method mapping', () {
    test('maps checkout labels to supported server values', () {
      expect(OrderService.paymentMethodForLabel('QRIS'), 'qris');
      expect(OrderService.paymentMethodForLabel('GoPay'), 'gopay');
      expect(
        OrderService.paymentMethodForLabel('Transfer Bank BCA'),
        'bank_transfer',
      );
      expect(
        OrderService.paymentMethodForLabel('Kartu Kredit / Debit'),
        'credit_card',
      );
      expect(
        OrderService.paymentMethodForLabel('Bayar di Toko (COD)'),
        'store_payment',
      );
      expect(
        OrderService.paymentMethodForLabel('COD (Bayar di Tempat)'),
        'cod',
      );
    });

    test('maps store pickup separately from courier fulfillment', () {
      expect(
        OrderService.fulfillmentMethodForLabel('Ambil di Toko'),
        'store_pickup',
      );
      expect(
        OrderService.fulfillmentMethodForLabel('Pengiriman Kurir'),
        'courier',
      );
      expect(
        () => OrderService.fulfillmentMethodForLabel('Metode lain'),
        throwsArgumentError,
      );
    });
  });

  group('OrderService cancellation eligibility', () {
    test('allows pending online payment and unpaid cash/store orders', () {
      expect(
        OrderService.canCancelOrder({
          'status': 'pending_payment',
          'payment_status': 'pending',
        }),
        isTrue,
      );
      expect(
        OrderService.canCancelOrder({
          'status': 'processing',
          'payment_status': 'cash_due',
        }),
        isTrue,
      );
      expect(
        OrderService.canCancelOrder({
          'statusCode': 'processing',
          'status': 'Perlu Diproses',
          'payment_status': 'store_due',
        }),
        isTrue,
      );
    });

    test('does not allow cancellation after payment or fulfillment starts', () {
      expect(
        OrderService.canCancelOrder({
          'status': 'processing',
          'payment_status': 'paid',
        }),
        isFalse,
      );
      expect(
        OrderService.canCancelOrder({
          'status': 'shipped',
          'payment_status': 'paid',
        }),
        isFalse,
      );
    });
  });

  group('OrderService action reconciliation', () {
    test('recognizes cancellation from the refreshed server state', () {
      expect(
        OrderService.isActionComplete('cancel', {'statusCode': 'cancelled'}),
        isTrue,
      );
      expect(
        OrderService.isActionComplete('cancel', {
          'statusCode': 'processing',
          'payment_status': 'cash_due',
        }),
        isFalse,
      );
    });
  });
}
