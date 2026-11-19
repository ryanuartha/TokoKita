import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/bounce_button.dart';
import 'product_dashboard.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({
    super.key,
    required this.totalAmount,
    required this.paymentMethod,
    required this.userName,
  });

  final int totalAmount;
  final String paymentMethod;
  final String userName;

  static String _formatRupiah(int value) {
    final valStr = value.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valStr.replaceAllMapped(reg, (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final orderId =
        'TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    return Scaffold(
      backgroundColor: AppColors.cardSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Success Animated Check Icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.stockAvailableBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.stockAvailableText,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Yeay, Pesanan Berhasil! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Makasih banyak ya, $userName! Pembayaran via $paymentMethod sudah kami terima dan pesananmu siap dikirim.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Order Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildRowInfo('Nomor Pesanan', orderId),
                    const Divider(height: 20, color: AppColors.border),
                    _buildRowInfo('Cara Bayar', paymentMethod),
                    const Divider(height: 20, color: AppColors.border),
                    _buildRowInfo('Estimasi Sampai', '2 - 3 Hari Kerja'),
                    const Divider(height: 20, color: AppColors.border),
                    _buildRowInfo(
                      'Total Tagihan',
                      _formatRupiah(totalAmount),
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Action Buttons
              BounceButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          ProductDashboard(userName: userName),
                    ),
                    (route) => false,
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Kembali ke Beranda',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowInfo(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? AppColors.primary : AppColors.textPrimary,
            fontSize: isHighlight ? 15 : 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
