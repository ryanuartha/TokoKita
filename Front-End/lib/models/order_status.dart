class OrderStatus {
  OrderStatus._();

  static const String waitingForPayment = 'Menunggu Bayar';
  static const String toProcess = 'Perlu Diproses';
  static const String shipped = 'Dikirim';
  static const String readyForPickup = 'Siap Diambil';
  static const String completed = 'Pesanan Selesai';
  static const String cancelled = 'Dibatalkan';
}
