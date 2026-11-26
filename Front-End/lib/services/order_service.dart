import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

class CreatedOrder {
  const CreatedOrder({
    required this.id,
    required this.displayId,
    required this.totalAmount,
    required this.status,
    this.paymentUrl,
    this.expiresAt,
  });

  final String id;
  final String displayId;
  final int totalAmount;
  final String status;
  final String? paymentUrl;
  final DateTime? expiresAt;
}

class OrderService {
  static String paymentMethodForLabel(String label) {
    if (label.contains('QRIS')) return 'qris';
    if (label.contains('GoPay')) return 'gopay';
    if (label.contains('Transfer')) return 'bank_transfer';
    if (label.contains('Kartu') || label.contains('Kredit')) {
      return 'credit_card';
    }
    if (label.contains('Toko')) return 'store_payment';
    if (label.contains('COD')) return 'cod';
    throw ArgumentError.value(label, 'label', 'Metode pembayaran tidak valid');
  }

  static String fulfillmentMethodForLabel(String label) {
    if (label == 'Ambil di Toko') return 'store_pickup';
    if (label == 'Pengiriman Kurir') return 'courier';
    throw ArgumentError.value(label, 'label', 'Metode penerimaan tidak valid');
  }

  static bool canCancelOrder(Map<String, dynamic> order) {
    final status = order['statusCode'] ?? order['status'];
    return status == 'pending_payment' ||
        (status == 'processing' &&
            const {'cash_due', 'store_due'}.contains(order['payment_status']));
  }

  static bool isActionComplete(String action, Map<String, dynamic> order) {
    final status = order['statusCode'] ?? order['status'];
    return switch (action) {
      'cancel' => status == 'cancelled',
      'dispatch' =>
        order['fulfillmentMethod'] == 'Ambil di Toko'
            ? status == 'ready_for_pickup'
            : status == 'shipped',
      'mark_delivered' =>
        order['deliveredAt'] != null || order['delivered_at'] != null,
      'confirm_received' || 'handover_pickup' => status == 'completed',
      'confirm_cash_payment' => order['payment_status'] == 'paid',
      _ => false,
    };
  }

  static Future<CreatedOrder> createOrder({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String fulfillmentMethod,
    required String shippingAddress,
    required String voucherCode,
    required double? shippingLatitude,
    required double? shippingLongitude,
  }) async {
    if ((shippingLatitude == null) != (shippingLongitude == null) ||
        (shippingLatitude != null &&
            (shippingLatitude < -90 || shippingLatitude > 90)) ||
        (shippingLongitude != null &&
            (shippingLongitude < -180 || shippingLongitude > 180))) {
      throw ArgumentError('Titik alamat tidak valid.');
    }

    final body = <String, dynamic>{
      'items': items,
      'payment_method': paymentMethod,
      'fulfillment_method': fulfillmentMethod,
      'shipping_address': shippingAddress,
      'voucher_code': voucherCode,
    };
    if (shippingLatitude != null && shippingLongitude != null) {
      body['shipping_latitude'] = shippingLatitude;
      body['shipping_longitude'] = shippingLongitude;
    }
    final data = _responseData(
      await _invokeFunction('create-payment', body: body),
    );
    return CreatedOrder(
      id: data['order_id'] as String,
      displayId: data['display_id'] as String,
      totalAmount: data['total_amount'] as int,
      status: data['status'] as String,
      paymentUrl: data['payment_url'] as String?,
      expiresAt: data['expires_at'] == null
          ? null
          : DateTime.parse(data['expires_at'] as String),
    );
  }

  static Future<List<Map<String, dynamic>>> loadOrders() async {
    final response = await AuthService.client
        .from('orders')
        .select('*, order_items(*)')
        .order('created_at', ascending: false);
    return response.map(_toDisplayOrder).toList();
  }

  static Future<Map<String, dynamic>> loadOrder(String id) async {
    final response = await AuthService.client
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', id)
        .single();
    return _toDisplayOrder(response);
  }

  static Future<void> performAction({
    required String orderId,
    required String action,
    String? trackingNumber,
  }) async {
    final body = <String, dynamic>{'order_id': orderId, 'action': action};
    if (trackingNumber != null) {
      body['tracking_number'] = trackingNumber;
    }
    await _invokeFunction('order-action', body: body);
  }

  static Future<dynamic> _invokeFunction(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await AuthService.client.functions.invoke(
        functionName,
        body: body,
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw StateError(details['error'] as String);
      }
      rethrow;
    }
  }

  static Map<String, dynamic> _responseData(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Respons server tidak valid.');
    }
    if (response['error'] is String) {
      throw StateError(response['error'] as String);
    }
    return Map<String, dynamic>.from(response);
  }

  static Map<String, dynamic> _toDisplayOrder(Map<String, dynamic> order) {
    final items = (order['order_items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final quantity = items.fold<int>(
      0,
      (sum, item) => sum + (item['quantity'] as int),
    );
    final firstItem = items.isEmpty ? null : items.first;
    final firstItemVariants = [
      if (firstItem?['variant_size'] is String)
        'Ukuran ${firstItem!['variant_size']}',
      if (firstItem?['variant_color'] is String)
        firstItem!['variant_color'] as String,
    ];
    final firstItemName = firstItem?['product_name'] as String?;
    final status = switch (order['status']) {
      'pending_payment' => 'Menunggu Bayar',
      'processing' => 'Perlu Diproses',
      'shipped' => 'Dikirim',
      'ready_for_pickup' => 'Siap Diambil',
      'completed' => 'Pesanan Selesai',
      'cancelled' => 'Dibatalkan',
      _ => order['status'] as String,
    };

    return {
      ...order,
      'id': order['id'],
      'orderId': order['display_id'],
      'statusCode': order['status'],
      'date': DateTime.parse(
        order['created_at'] as String,
      ).toLocal().toString(),
      'status': status,
      'productName': [
        firstItemName ?? 'Pesanan TokoKita',
        if (firstItemVariants.isNotEmpty) firstItemVariants.join(' · '),
      ].join(' — '),
      'qty': quantity,
      'totalPrice': _formatRupiah(order['total_amount'] as int),
      'image': firstItem?['image_asset'] ?? '',
      'trackingNumber': order['tracking_number'] ?? '',
      'pickupCode': order['pickup_code'] ?? '',
      'paymentMethod': order['payment_method'],
      'fulfillmentMethod': order['fulfillment_method'] == 'store_pickup'
          ? 'Ambil di Toko'
          : 'Pengiriman Kurir',
      'shippingAddress': order['shipping_address'],
      'shippingLatitude': (order['shipping_latitude'] as num?)?.toDouble(),
      'shippingLongitude': (order['shipping_longitude'] as num?)?.toDouble(),
      'deliveredAt': order['delivered_at'],
    };
  }

  static String _formatRupiah(int value) {
    final valueText = value.toString();
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valueText.replaceAllMapped(pattern, (match) => '${match[1]}.')}';
  }
}
