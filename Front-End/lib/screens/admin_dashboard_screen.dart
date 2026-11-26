import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_status.dart';
import 'admin_inventory_screen.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import 'support_inbox_screen.dart';
import 'welcome_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.adminName,
    required this.adminEmail,
  });

  final String adminName;
  final String adminEmail;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = OrderService.loadOrders();
  }

  Future<void> _logout() async {
    if (AuthService.currentUser != null) {
      await AuthService.client.auth.signOut();
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageTitles = [
      'Ringkasan',
      'Produk & inventaris',
      'Pesanan',
      'Chat pembeli',
      'Laporan',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          pageTitles[_currentIndex],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui data',
            onPressed: () {
              setState(() => _ordersFuture = OrderService.loadOrders());
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildOverview(),
          _buildInventory(),
          _buildOrders(),
          const SupportInboxScreen(),
          _buildReports(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Ringkasan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Produk',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingState('Memuat ringkasan toko');
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            title: 'Ringkasan belum tersedia',
            message: 'Periksa koneksi, lalu coba muat ulang data toko.',
          );
        }

        final orders = snapshot.data ?? const [];
        final paidTotal = orders
            .where((order) => order['payment_status'] == 'paid')
            .fold<int>(
              0,
              (total, order) => total + (order['total_amount'] as int),
            );
        final pendingCount = orders
            .where((order) => order['status'] == 'Menunggu Bayar')
            .length;
        final processingCount = orders
            .where((order) => order['status'] == 'Perlu Diproses')
            .length;
        final cashDueCount = orders
            .where((order) => order['payment_status'] == 'cash_due')
            .length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAdminWelcome(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pembayaran diterima',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRupiah(paidTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Total transaksi dengan status lunas',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _buildSectionHeading(
              'Performa toko',
              caption: 'Ringkasan seluruh pesanan',
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _AdminMetricCard(
                  title: 'Sedang diproses',
                  value: '$processingCount',
                  supportingText: 'Perlu ditangani',
                  icon: Icons.payments_rounded,
                  iconColor: AppColors.primary,
                ),
                _AdminMetricCard(
                  title: 'Menunggu pembayaran',
                  value: '$pendingCount',
                  supportingText: 'Belum lunas',
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFFB7791F),
                ),
                _AdminMetricCard(
                  title: 'COD belum diterima',
                  value: '$cashDueCount',
                  supportingText: 'Perlu konfirmasi',
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF5B63B7),
                ),
                _AdminMetricCard(
                  title: 'Total pesanan',
                  value: '${orders.length}',
                  supportingText: 'Semua status',
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppColors.accentTeal,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _buildSectionHeading(
              'Perlu perhatian',
              caption: 'Tindak lanjuti agar pesanan tetap lancar',
            ),
            const SizedBox(height: 12),
            _buildAttentionCard(
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFFB7791F),
              title: '$processingCount pesanan perlu diproses',
              description: processingCount == 0
                  ? 'Semua pesanan baru sudah ditangani.'
                  : 'Periksa detail pesanan dan perbarui status pengiriman.',
            ),
            const SizedBox(height: 10),
            _buildAttentionCard(
              icon: Icons.payments_outlined,
              color: const Color(0xFF5B63B7),
              title: '$cashDueCount pembayaran COD belum diterima',
              description:
                  'Konfirmasi pembayaran setelah dana diterima dari kurir.',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 19,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pendapatan hanya menghitung pesanan yang telah lunas. '
                      'Pesanan COD yang belum diterima belum termasuk.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatRupiah(int value) {
    final digits = value.toString();
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${digits.replaceAllMapped(pattern, (match) => '${match[1]}.')}';
  }

  Widget _buildInventory() {
    return const AdminInventoryScreen();
  }

  Widget _buildOrders() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingState('Memuat pesanan');
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            title: 'Pesanan belum dapat dimuat',
            message: 'Periksa koneksi, lalu coba muat ulang data pesanan.',
          );
        }
        final orders = snapshot.data ?? const [];
        if (orders.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPageIntro(
                title: 'Pesanan',
                description: 'Kelola dan pantau pesanan pelanggan.',
              ),
              const SizedBox(height: 18),
              _buildEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada pesanan',
                message:
                    'Pesanan baru dari pelanggan akan muncul di halaman ini.',
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPageIntro(
                  title: 'Pesanan',
                  description:
                      '${orders.length} pesanan tercatat di toko Anda.',
                ),
              );
            }
            final order = orders[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOrderCard(order),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String;
    final fulfillmentMethod = order['fulfillmentMethod'] as String?;
    final latitude = (order['shippingLatitude'] as num?)?.toDouble();
    final longitude = (order['shippingLongitude'] as num?)?.toDouble();
    final trackingNumber = order['trackingNumber'] as String? ?? '';
    final pickupCode = order['pickupCode'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOMOR PESANAN',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${order['orderId']}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            order['productName'] as String? ?? 'Pesanan TokoKita',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${order['qty']} barang',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.payments_outlined,
                label: (order['paymentMethod'] as String? ?? '-').toUpperCase(),
              ),
              _InfoPill(
                icon: fulfillmentMethod == 'Ambil di Toko'
                    ? Icons.storefront_outlined
                    : Icons.local_shipping_outlined,
                label: fulfillmentMethod ?? 'Pengiriman Kurir',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total pesanan',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                order['totalPrice'] as String? ?? '-',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (fulfillmentMethod == 'Pengiriman Kurir' &&
              (order['shippingAddress'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _OrderDetailLine(
              icon: Icons.location_on_outlined,
              text: order['shippingAddress'] as String,
            ),
          ],
          if (trackingNumber.isNotEmpty) ...[
            const SizedBox(height: 8),
            _OrderDetailLine(
              icon: Icons.local_shipping_outlined,
              text: 'Resi: $trackingNumber',
            ),
          ],
          if (pickupCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            _OrderDetailLine(
              icon: Icons.pin_outlined,
              text: 'Kode pickup: $pickupCode',
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (latitude != null && longitude != null)
                OutlinedButton.icon(
                  onPressed: () => _openGoogleMaps(latitude, longitude),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Lihat lokasi'),
                ),
              if (status == OrderStatus.toProcess)
                OutlinedButton.icon(
                  onPressed: () => _dispatchOrder(order),
                  icon: Icon(
                    fulfillmentMethod == 'Ambil di Toko'
                        ? Icons.storefront_outlined
                        : Icons.local_shipping_outlined,
                    size: 18,
                  ),
                  label: Text(
                    fulfillmentMethod == 'Ambil di Toko'
                        ? 'Siapkan pesanan'
                        : 'Masukkan resi',
                  ),
                ),
              if (status == OrderStatus.shipped &&
                  order['deliveredAt'] == null)
                OutlinedButton(
                  onPressed: () => _performOrderAction(
                    order['id'] as String,
                    'mark_delivered',
                  ),
                  child: const Text('Tandai tiba'),
                ),
              if (order['payment_status'] == 'cash_due' &&
                  (status == OrderStatus.shipped ||
                      status == OrderStatus.completed))
                OutlinedButton(
                  onPressed: () => _performOrderAction(
                    order['id'] as String,
                    'confirm_cash_payment',
                  ),
                  child: const Text('Konfirmasi COD'),
                ),
              if (status == OrderStatus.readyForPickup)
                ElevatedButton(
                  onPressed: () => _performOrderAction(
                    order['id'] as String,
                    'handover_pickup',
                  ),
                  child: const Text('Konfirmasi serah terima'),
                ),
              if (status == OrderStatus.waitingForPayment ||
                  (status == OrderStatus.toProcess &&
                      order['payment_status'] != 'paid'))
                TextButton(
                  onPressed: () =>
                      _confirmAdminCancellation(order['id'] as String),
                  child: const Text('Batalkan'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps tidak dapat dibuka.')),
      );
    }
  }

  Future<void> _performOrderAction(
    String orderId,
    String action, {
    String? trackingNumber,
  }) async {
    Object? actionError;
    try {
      await OrderService.performAction(
        orderId: orderId,
        action: action,
        trackingNumber: trackingNumber,
      );
    } catch (error) {
      actionError = error;
    }

    if (!mounted) return;
    try {
      final refreshedOrdersFuture = OrderService.loadOrders();
      setState(() => _ordersFuture = refreshedOrdersFuture);
      if (actionError == null) return;

      final refreshedOrders = await refreshedOrdersFuture;
      if (!mounted) return;
      final matchingOrders = refreshedOrders.where(
        (order) => order['id'] == orderId,
      );
      if (matchingOrders.isNotEmpty &&
          OrderService.isActionComplete(action, matchingOrders.first)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'cancel'
                  ? 'Pesanan berhasil dibatalkan.'
                  : 'Perubahan pesanan berhasil disimpan.',
            ),
          ),
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Status pesanan belum dapat dipastikan. Muat ulang untuk memastikan.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final message = actionError is StateError
        ? actionError.message.toString()
        : 'Pesanan belum berhasil diperbarui. Periksa koneksi, lalu coba lagi.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildReports() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingState('Menyiapkan laporan');
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            title: 'Laporan belum tersedia',
            message: 'Data transaksi belum dapat dimuat. Coba lagi sebentar.',
          );
        }

        final orders = snapshot.data ?? const [];
        final paidOrders = orders
            .where((order) => order['payment_status'] == 'paid')
            .toList();
        final paidTotal = paidOrders.fold<int>(
          0,
          (total, order) => total + (order['total_amount'] as int),
        );
        final averagePaidOrder = paidOrders.isEmpty
            ? 0
            : paidTotal ~/ paidOrders.length;
        const statusRows = [
          ('Menunggu pembayaran', 'pending_payment', Color(0xFFB7791F)),
          ('Perlu diproses', 'processing', AppColors.primary),
          ('Dalam pengiriman', 'shipped', Color(0xFF5B63B7)),
          ('Siap diambil', 'ready_for_pickup', Color(0xFF5B63B7)),
          ('Selesai', 'completed', AppColors.accentTeal),
          ('Dibatalkan', 'cancelled', AppColors.textMuted),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPageIntro(
              title: 'Laporan toko',
              description: 'Ringkasan transaksi dan status seluruh pesanan.',
            ),
            const SizedBox(height: 18),
            if (orders.isEmpty)
              _buildEmptyState(
                icon: Icons.bar_chart_rounded,
                title: 'Belum ada data laporan',
                message: 'Ringkasan akan terisi setelah toko menerima pesanan.',
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PENDAPATAN TERVERIFIKASI',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatRupiah(paidTotal),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${paidOrders.length} transaksi lunas dari ${orders.length} pesanan',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AdminMetricCard(
                      title: 'Total pesanan',
                      value: '${orders.length}',
                      supportingText: 'Semua status',
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdminMetricCard(
                      title: 'Rata-rata lunas',
                      value: _formatRupiah(averagePaidOrder),
                      supportingText: 'Per transaksi',
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.accentTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildSectionHeading(
                'Status pesanan',
                caption: 'Distribusi seluruh pesanan',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < statusRows.length; index++) ...[
                      _ReportStatusRow(
                        label: statusRows[index].$1,
                        count: orders
                            .where(
                              (order) =>
                                  order['statusCode'] == statusRows[index].$2,
                            )
                            .length,
                        total: orders.length,
                        color: statusRows[index].$3,
                      ),
                      if (index != statusRows.length - 1)
                        const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentTealLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: AppColors.accentTeal,
                      size: 18,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Pendapatan hanya menjumlahkan transaksi dengan '
                        'status pembayaran lunas. COD yang belum diterima '
                        'tidak dihitung.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAdminWelcome() {
    final nameParts = widget.adminName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.accentSoft,
          child: Text(
            nameParts.isEmpty ? 'TK' : nameParts,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang, ${widget.adminName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.adminEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentTealLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'ADMIN',
            style: TextStyle(
              color: AppColors.accentTeal,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIntro({required String title, required String description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(String title, {required String caption}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          caption,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAttentionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.textMuted,
                size: 38,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _ordersFuture = OrderService.loadOrders());
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.textMuted, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAdminCancellation(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Pesanan akan dibatalkan dan stoknya dikembalikan. Tindakan ini '
          'tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Batalkan pesanan'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _performOrderAction(orderId, 'cancel');
  }

  Future<void> _dispatchOrder(Map<String, dynamic> order) async {
    final orderId = order['id'] as String;
    if (order['fulfillmentMethod'] == 'Ambil di Toko') {
      await _performOrderAction(orderId, 'dispatch');
      return;
    }

    final controller = TextEditingController();
    final trackingNumber = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Masukkan nomor resi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Contoh: JNE123456789'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Simpan dan kirim'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (trackingNumber == null || !mounted) return;
    await _performOrderAction(
      orderId,
      'dispatch',
      trackingNumber: trackingNumber,
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.title,
    required this.value,
    required this.supportingText,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String supportingText;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            supportingText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.waitingForPayment => const Color(0xFFB7791F),
      OrderStatus.shipped ||
      OrderStatus.readyForPickup => const Color(0xFF5B63B7),
      OrderStatus.completed => AppColors.accentTeal,
      OrderStatus.cancelled => AppColors.textMuted,
      _ => AppColors.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailLine extends StatelessWidget {
  const _OrderDetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportStatusRow extends StatelessWidget {
  const _ReportStatusRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : count / total,
            minHeight: 6,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
