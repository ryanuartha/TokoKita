import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/order_service.dart';
import '../theme/app_colors.dart';
import 'order_success_screen.dart';

class PaymentGatewayScreen extends StatefulWidget {
  const PaymentGatewayScreen({
    super.key,
    required this.totalAmount,
    required this.paymentMethod,
    required this.userName,
    required this.userEmail,
    required this.shippingAddress,
    required this.orderId,
    required this.displayId,
    this.paymentUrl,
    this.expiresAt,
  });

  final int totalAmount;
  final String paymentMethod;
  final String userName;
  final String userEmail;
  final String shippingAddress;
  final String orderId;
  final String displayId;
  final String? paymentUrl;
  final DateTime? expiresAt;

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  Map<String, dynamic>? _order;
  String? _errorMessage;
  bool _isOpeningPayment = false;
  bool _hasNavigatedToSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshOrder();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshOrder(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOrder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    try {
      final order = await OrderService.loadOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _errorMessage = null;
      });

      final paymentStatus = order['payment_status'];
      if (!_hasNavigatedToSuccess &&
          (paymentStatus == 'paid' ||
              paymentStatus == 'cash_due' ||
              paymentStatus == 'store_due')) {
        _hasNavigatedToSuccess = true;
        _pollTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => OrderSuccessScreen(
              totalAmount: widget.totalAmount,
              paymentMethod: widget.paymentMethod,
              userName: widget.userName,
              userEmail: widget.userEmail,
              orderId: widget.displayId,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _openPaymentPage() async {
    final paymentUrl = widget.paymentUrl;
    if (paymentUrl == null) return;
    final uri = Uri.tryParse(paymentUrl);
    if (uri == null || !{'https', 'http'}.contains(uri.scheme)) {
      setState(
        () => _errorMessage =
            'Tautan pembayaran tidak dapat digunakan. Coba perbarui status pesanan.',
      );
      return;
    }

    setState(() => _isOpeningPayment = true);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Halaman pembayaran belum bisa dibuka. Coba lagi.');
      }
      await _refreshOrder();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isOpeningPayment = false);
    }
  }

  String _formatRupiah(int value) {
    final digits = value.toString();
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${digits.replaceAllMapped(pattern, (match) => '${match[1]}.')}';
  }

  String _statusLabel() {
    final status = _order?['status'] as String?;
    if (status == 'Dibatalkan') return 'Pesanan dibatalkan';
    if (_order?['payment_status'] == 'paid') {
      return 'Pembayaran diterima. Pesanan menunggu disiapkan.';
    }
    if (_order?['payment_status'] == 'cash_due' ||
        _order?['payment_status'] == 'store_due') {
      return 'Pesanan tercatat. Pembayaran dilakukan saat barang diterima atau diambil.';
    }
    return 'Menunggu konfirmasi pembayaran.';
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = _order?['status'] == 'Dibatalkan';
    final remaining = widget.expiresAt?.difference(DateTime.now());
    final expired = remaining?.isNegative ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Pembayaran'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCancelled
                          ? Icons.cancel_outlined
                          : Icons.lock_clock_outlined,
                      size: 52,
                      color: isCancelled ? Colors.red : AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatRupiah(widget.totalAmount),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pesanan #${widget.displayId}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusLabel(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.paymentUrl != null && !isCancelled) ...[
                      const SizedBox(height: 8),
                      Text(
                        expired
                            ? 'Batas waktu pembayaran sudah lewat. Periksa status pesanan untuk mengetahui langkah berikutnya.'
                            : 'Lanjutkan pembayaran di halaman Midtrans.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isOpeningPayment
                              ? null
                              : _openPaymentPage,
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            _isOpeningPayment
                                ? 'Membuka halaman pembayaran...'
                                : 'Lanjutkan ke pembayaran',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_order == null)
                      const CircularProgressIndicator()
                    else
                      TextButton.icon(
                        onPressed: _refreshOrder,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Cek status pembayaran'),
                      ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
