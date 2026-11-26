import 'package:material_ui/material_ui.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.productName,
    required this.totalPrice,
    required this.status,
    required this.imageAsset,
    required this.date,
    this.orderData,
  });

  final String orderId;
  final String productName;
  final String totalPrice;
  final String status;
  final String imageAsset;
  final String date;
  final Map<String, dynamic>? orderData;

  @override
  Widget build(BuildContext context) {
    final order = orderData;
    final currentStatus = order?['status'] as String? ?? status;
    final fulfillmentMethod = order?['fulfillmentMethod'] as String?;
    final pickupCode = order?['pickupCode'] as String?;
    final isDelivered =
        currentStatus == OrderStatus.completed || currentStatus == 'Selesai';
    final statusColor = isDelivered ? AppColors.accentTeal : AppColors.primary;

    final timelineSteps = <Map<String, String>>[];
    if (currentStatus == OrderStatus.waitingForPayment) {
      timelineSteps.add({
        'title': 'Menunggu Pembayaran',
        'desc': 'Selesaikan pembayaran sebelum batas waktunya berakhir.',
        'time': date,
      });
    } else if (currentStatus == OrderStatus.cancelled) {
      timelineSteps.add({
        'title': 'Pesanan Dibatalkan',
        'desc': 'Pesanan ini dibatalkan atau waktu pembayaran telah habis.',
        'time': date,
      });
    } else if (currentStatus == OrderStatus.readyForPickup) {
      timelineSteps.add({
        'title': 'Siap Diambil di Toko',
        'desc': 'Tunjukkan kode pengambilan kepada petugas toko.',
        'time': date,
      });
    } else if (currentStatus == OrderStatus.toProcess) {
      timelineSteps.addAll([
        {
          'title': 'Pembayaran Dikonfirmasi',
          'desc': 'Pembayaran sudah diterima. Pesanan akan segera disiapkan.',
          'time': date,
        },
        {
          'title': 'Perlu Diproses',
          'desc': 'Toko sedang menyiapkan pesanan Anda.',
          'time': 'Menunggu',
        },
      ]);
    } else if (currentStatus == OrderStatus.shipped ||
        currentStatus.toLowerCase().contains('dikirim')) {
      final trackingNumber = order?['trackingNumber'] as String?;
      timelineSteps.add({
        'title': order?['deliveredAt'] == null
            ? 'Pesanan Dikirim'
            : 'Paket Telah Tiba',
        'desc': trackingNumber == null || trackingNumber.isEmpty
            ? 'Pesanan telah diserahkan kepada kurir.'
            : 'Nomor resi: $trackingNumber',
        'time': date,
      });
      if (order?['deliveredAt'] != null) {
        timelineSteps.add({
          'title': 'Konfirmasi Penerimaan',
          'desc': 'Konfirmasikan penerimaan pesanan melalui Riwayat Pesanan.',
          'time': 'Menunggu',
        });
      }
    } else if (isDelivered) {
      timelineSteps.add({
        'title': 'Pesanan Selesai',
        'desc': 'Pesanan selesai. Terima kasih sudah berbelanja di TokoKita.',
        'time': date,
      });
    } else {
      timelineSteps.add({
        'title': currentStatus,
        'desc': 'Kami akan menampilkan pembaruan pesanan di sini.',
        'time': date,
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Lacak Pesanan #$orderId',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Info Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      imageAsset,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: 64,
                        height: 64,
                        color: AppColors.background,
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalPrice,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currentStatus,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delivery Address Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Cara menerima pesanan',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fulfillmentMethod ?? 'Pengiriman ke alamat',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    (order?['shippingAddress'] as String?) ??
                        'Alamat pengiriman belum tersedia.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  if (pickupCode != null && pickupCode.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Kode pengambilan: $pickupCode',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Logistics Timeline Tracking Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perkembangan Pesanan',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: timelineSteps.length,
                    itemBuilder: (context, index) {
                      final step = timelineSteps[index];
                      final isFirst = index == 0;
                      final isLast = index == timelineSteps.length - 1;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isFirst
                                      ? AppColors.primary
                                      : AppColors.border,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isFirst
                                        ? AppColors.primary.withAlpha(100)
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 48,
                                  color: AppColors.border,
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step['title'] as String,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: isFirst
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: isFirst
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step['desc'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step['time'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    color: AppColors.textMuted,
                                    fontSize: 10.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
