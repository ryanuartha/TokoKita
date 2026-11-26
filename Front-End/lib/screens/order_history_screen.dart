import 'package:material_ui/material_ui.dart';

import '../models/order_status.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key, this.initialFilter = 'Semua'});

  final String initialFilter;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late String _selectedFilter;
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  String? _processingOrderId;

  final List<String> _filters = [
    'Semua',
    'Belum Bayar',
    'Dikemas',
    'Dikirim',
    'Selesai',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _ordersFuture = OrderService.loadOrders();
  }

  Future<void> _performOrderAction(String orderId, String action) async {
    if (_processingOrderId != null) return;
    setState(() => _processingOrderId = orderId);
    try {
      await OrderService.performAction(orderId: orderId, action: action);
      if (mounted) {
        setState(() => _ordersFuture = OrderService.loadOrders());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'cancel'
                  ? 'Pesanan berhasil dibatalkan.'
                  : 'Penerimaan pesanan berhasil dikonfirmasi.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : 'Pesanan belum berhasil diperbarui. Periksa koneksi, lalu coba lagi.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _processingOrderId = null);
    }
  }

  Future<void> _confirmCancellation(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Pesanan akan dibatalkan dan stoknya dikembalikan. Pembatalan tidak '
          'dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Jangan batalkan'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _performOrderAction(orderId, 'cancel');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Riwayat Pesanan')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pesanan belum bisa dimuat. Periksa koneksi, lalu coba lagi.',
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _ordersFuture = OrderService.loadOrders(),
                    ),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        final allOrders = snapshot.data ?? const <Map<String, dynamic>>[];

        final filteredOrders = allOrders.where((o) {
          if (_selectedFilter == 'Semua') return true;
          final st = (o['status'] as String).toLowerCase();
          final filter = _selectedFilter.toLowerCase();
          if (filter.contains('dikirim')) {
            return st.contains('dikirim') || st.contains('diambil');
          }
          if (filter.contains('dikemas')) {
            return st == OrderStatus.toProcess.toLowerCase();
          }
          if (filter.contains('selesai')) {
            return st == OrderStatus.completed.toLowerCase();
          }
          if (filter.contains('belum')) {
            return st == OrderStatus.waitingForPayment.toLowerCase();
          }
          return st == filter;
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.cardSurface,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Riwayat Pesanan',
              style: TextStyle(
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
          body: Column(
            children: [
              // Filter Tab Bar
              Container(
                height: 44,
                color: AppColors.cardSurface,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada pesanan di kategori "$_selectedFilter".',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          final status = order['status'] as String;
                          final canCancel = OrderService.canCancelOrder(order);
                          final isProcessing =
                              _processingOrderId == order['id'];
                          final statusColor = status.contains('Selesai')
                              ? AppColors.accentTeal
                              : AppColors.primary;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => OrderTrackingScreen(
                                    orderId: order['orderId'] as String,
                                    productName: order['productName'] as String,
                                    totalPrice: order['totalPrice'] as String,
                                    status: status,
                                    imageAsset: order['image'] as String,
                                    date: order['date'] as String,
                                    orderData: order,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(8),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'No. Pesanan: #${order['orderId']}',
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withAlpha(25),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          status,
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
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(
                                      color: AppColors.border,
                                      height: 1,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          order['image'] as String,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) =>
                                              Container(
                                                width: 64,
                                                height: 64,
                                                color: AppColors.background,
                                                child: const Icon(
                                                  Icons.shopping_bag_outlined,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order['productName'] as String,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'PlusJakartaSans',
                                                color: AppColors.textPrimary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${order['qty']} barang • ${order['date']}',
                                              style: const TextStyle(
                                                fontFamily: 'Roboto',
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(
                                      color: AppColors.border,
                                      height: 1,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total Belanja',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          color: AppColors.textSecondary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      Text(
                                        order['totalPrice'] as String,
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          color: AppColors.primary,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (canCancel ||
                                      (status == OrderStatus.shipped &&
                                          order['deliveredAt'] != null)) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: canCancel
                                          ? TextButton.icon(
                                              onPressed:
                                                  _processingOrderId == null
                                                  ? () => _confirmCancellation(
                                                      order['id'] as String,
                                                    )
                                                  : null,
                                              icon: isProcessing
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.cancel_outlined,
                                                    ),
                                              label: Text(
                                                isProcessing
                                                    ? 'Membatalkan...'
                                                    : 'Batalkan Pesanan',
                                              ),
                                            )
                                          : FilledButton(
                                              onPressed: () =>
                                                  _processingOrderId == null
                                                  ? _performOrderAction(
                                                      order['id'] as String,
                                                      'confirm_received',
                                                    )
                                                  : null,
                                              child: const Text(
                                                'Pesanan Diterima',
                                              ),
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
