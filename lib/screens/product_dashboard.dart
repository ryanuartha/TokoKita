import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/product_data.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';
import '../widgets/bounce_button.dart';
import '../widgets/product_card_grid.dart';
import 'order_success_screen.dart';
import 'product_detail_screen.dart';
import 'welcome_screen.dart';

class ProductDashboard extends StatefulWidget {
  const ProductDashboard({super.key, required this.userName});

  final String userName;

  @override
  State<ProductDashboard> createState() => _ProductDashboardState();
}

class _ProductDashboardState extends State<ProductDashboard> {
  final PageController _promoPageController = PageController();
  int _currentPromoIndex = 0;
  Timer? _promoAutoScrollTimer;
  Timer? _countdownTimer;
  int _flashSaleSeconds = 6128; // 01:42:08 countdown

  String _searchQuery = '';
  int _currentNavIndex = 0; // 0: Beranda, 1: Favorit, 2: Keranjang, 3: Profil
  final _searchController = TextEditingController();

  final Set<String> _favoriteProductIds = {};
  final Set<String> _pendingUnfavoriteIds = {};
  final Set<String> _pendingRemoveCartIds = {};
  final Set<String> _cartAddedAnimIds = {};
  final Map<String, int> _cartItemQuantities = {};
  final Set<String> _cartItemChecked = {};
  bool _hasUnreadNotifications = true;
  String _selectedPaymentMethod = 'GoPay / QRIS';

  // State Kategori Global Terpadu
  String _selectedCategory = 'Semua';

  late String _profileName;
  late String _profileEmail;
  bool _hasCustomAvatar = false;
  late List<Product> _shuffledProducts;

  @override
  void initState() {
    super.initState();
    _profileName = widget.userName;
    _profileEmail =
        '${widget.userName.toLowerCase().replaceAll(' ', '')}@tokokita.id';
    _shuffledProducts = List<Product>.from(products)..shuffle();
    _startPromoAutoScroll();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _promoAutoScrollTimer?.cancel();
    _countdownTimer?.cancel();
    _promoPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalCartCount =>
      _cartItemQuantities.values.fold(0, (sum, count) => sum + count);

  List<Product> get _favoriteProducts {
    return products
        .where((product) => _favoriteProductIds.contains(product.id))
        .toList();
  }

  bool _isProductFavorite(String productId) {
    return _favoriteProductIds.contains(productId) &&
        !_pendingUnfavoriteIds.contains(productId);
  }

  List<MapEntry<Product, int>> get _cartProducts {
    final List<MapEntry<Product, int>> list = [];
    for (final entry in _cartItemQuantities.entries) {
      final match = products.where((p) => p.id == entry.key);
      if (match.isNotEmpty && entry.value > 0) {
        list.add(MapEntry(match.first, entry.value));
      }
    }
    return list;
  }

  int get _cartTotalPrice {
    int total = 0;
    for (final item in _cartProducts) {
      if (_cartItemChecked.contains(item.key.id)) {
        total += item.key.price * item.value;
      }
    }
    return total;
  }

  void _toggleFavorite(String productId) {
    final isFavBefore = _favoriteProductIds.contains(productId);
    if (isFavBefore) {
      setState(() {
        _pendingUnfavoriteIds.add(productId);
      });
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          setState(() {
            _favoriteProductIds.remove(productId);
            _pendingUnfavoriteIds.remove(productId);
          });
        }
      });
      _showSnackBar('Dihapus dari Favorit');
    } else {
      setState(() {
        _favoriteProductIds.add(productId);
      });
      _showSnackBar('Berhasil ditambahkan ke Favorit');
    }
  }

  void _addToCart(String productId, [int quantity = 1]) {
    setState(() {
      _cartItemQuantities[productId] =
          (_cartItemQuantities[productId] ?? 0) + quantity;
      _cartItemChecked.add(productId);
    });
  }

  void _updateCartQuantity(String productId, int delta) {
    setState(() {
      final current = _cartItemQuantities[productId] ?? 0;
      final newQty = current + delta;
      if (newQty <= 0) {
        _removeCartItem(productId);
      } else {
        _cartItemQuantities[productId] = newQty;
      }
    });
  }

  void _removeCartItem(String productId) {
    if (_cartItemQuantities.containsKey(productId)) {
      setState(() {
        _pendingRemoveCartIds.add(productId);
      });
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          setState(() {
            _cartItemQuantities.remove(productId);
            _pendingRemoveCartIds.remove(productId);
            _cartItemChecked.remove(productId);
          });
        }
      });
    }
  }

  void _openProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailScreen(
          product: product,
          isFavorite: _isProductFavorite(product.id),
          onFavoriteToggle: () => _toggleFavorite(product.id),
          onAddToCart: (qty) => _addToCart(product.id, qty),
          userName: _profileName,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _showSnackBar(String message) {}

  void _openProfilePhotoPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ubah Foto Profil',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Ambil Foto dari Kamera',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _hasCustomAvatar = true);
                  _showSnackBar('Foto profil diperbarui dari Kamera.');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _hasCustomAvatar = true);
                  _showSnackBar('Foto profil diperbarui dari Galeri.');
                },
              ),
              if (_hasCustomAvatar)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.accent,
                  ),
                  title: const Text(
                    'Hapus Foto Profil',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.accent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _hasCustomAvatar = false);
                    _showSnackBar('Foto profil dihapus.');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _openNotificationSheet() {
    setState(() => _hasUnreadNotifications = false);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final notifications = [
          {
            'icon': Icons.bolt_rounded,
            'title': 'Flash Sale 50% Dibuka!',
            'desc': 'Diskon besar untuk produk elektronik dan pakaian.',
            'time': '5 menit lalu',
          },
          {
            'icon': Icons.local_shipping_rounded,
            'title': 'Pesanan #TK-98234 Dikirim',
            'desc': 'Paket Anda sedang dibawa oleh kurir.',
            'time': '1 jam lalu',
          },
        ];

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifikasi',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 6),
              ...notifications.map((notif) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        notif['icon'] as IconData,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  notif['title'] as String,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  notif['time'] as String,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notif['desc'] as String,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openCheckoutModal() {
    if (_cartProducts.isEmpty) {
      _showSnackBar('Keranjang belanja Anda masih kosong.');
      return;
    }
    if (_cartItemChecked.isEmpty || _cartTotalPrice == 0) {
      _showSnackBar('Pilih minimal 1 produk untuk di-checkout.');
      return;
    }

    final total = _cartTotalPrice;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final paymentOptions = [
              {'name': 'GoPay / QRIS', 'desc': 'Saldo: Rp 1.250.000'},
              {'name': 'Transfer Bank BCA', 'desc': 'Virtual Account otomatis'},
              {'name': 'COD (Bayar di Tempat)', 'desc': 'Bayar tunai ke kurir'},
              {'name': 'Kartu Kredit / Debit', 'desc': 'Visa / Mastercard'},
            ];

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Checkout Pembayaran',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alamat: $_profileName',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Jl. Jend. Sudirman No. 45, Jakarta Selatan',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pilih Metode Pembayaran:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: paymentOptions.map((opt) {
                      final name = opt['name'] as String;
                      final desc = opt['desc'] as String;
                      final isSelected = _selectedPaymentMethod == name;

                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            _selectedPaymentMethod = name;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentSoft
                                : AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bayar:',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatRupiah(total),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => OrderSuccessScreen(
                              totalAmount: total,
                              paymentMethod: _selectedPaymentMethod,
                              userName: _profileName,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Bayar via $_selectedPaymentMethod',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openOrderHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final orders = [
          {
            'id': '#TK-98234',
            'status': 'Sedang Dikirim',
            'item': 'Smartphone Nova X Pro 5G',
            'total': 3499000,
          },
          {
            'id': '#TK-97102',
            'status': 'Selesai',
            'item': 'Hoodie Classic Fleece Premium',
            'total': 249000,
          },
        ];

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Pesanan',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 6),
              ...orders.map((order) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order['id'] as String,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            order['status'] as String,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order['item'] as String,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatRupiah(order['total'] as int),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openAddressSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Alamat Pengiriman',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rumah (Utama) • $_profileName',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Jl. Jend. Sudirman No. 45, Jakarta Selatan (0812-3456-7890)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPaymentMethodsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Metode Pembayaran',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 6),
              const ListTile(
                dense: true,
                leading: Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.primary,
                ),
                title: Text(
                  'GoPay / QRIS',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  'Saldo: Rp 1.250.000',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Icon(
                  Icons.check_circle,
                  color: AppColors.stockAvailableText,
                  size: 18,
                ),
              ),
              const ListTile(
                dense: true,
                leading: Icon(Icons.account_balance, color: AppColors.primary),
                title: Text(
                  'Transfer Bank BCA',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  'VA: 88012398234',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openHelpCenterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pusat Bantuan',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 6),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Live Chat CS 24 Jam',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnackBar('Terhubung dengan CS TokoKita.');
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.help_outline,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'FAQ & Cara Belanja',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnackBar('Membuka halaman bantuan.');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAccountSettingsSheet() {
    final nameController = TextEditingController(text: _profileName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pengaturan Akun',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              const Text(
                'Nama Lengkap',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _profileName = nameController.text.trim();
                      _profileEmail =
                          '${_profileName.toLowerCase().replaceAll(' ', '')}@tokokita.id';
                    });
                    Navigator.pop(ctx);
                    _showSnackBar('Profil berhasil diperbarui.');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Simpan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildTopBar() {
    if (_currentNavIndex == 0) {
      // BERANDA TOP BAR
      return PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.cardSurface,
          elevation: 0,
          titleSpacing: 16,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Halo, $_profileName 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Belanja hemat & terpercaya',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _openNotificationSheet,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              icon: Stack(
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                  if (_hasUnreadNotifications)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _currentNavIndex = 2),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              icon: Stack(
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                  if (_totalCartCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_totalCartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    } else if (_currentNavIndex == 1) {
      // FAVORIT TOP BAR
      return PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.cardSurface,
          elevation: 0,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Produk Favorit Saya',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_favoriteProducts.length} produk tersimpan',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => setState(() => _currentNavIndex = 2),
              icon: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    } else if (_currentNavIndex == 2) {
      // KERANJANG TOP BAR
      return PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.cardSurface,
          elevation: 0,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Keranjang Belanja',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$_totalCartCount barang di keranjang',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _openNotificationSheet,
              icon: const Icon(
                Icons.notifications_outlined,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    } else {
      // PROFIL TOP BAR
      return PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.cardSurface,
          elevation: 0,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Profil Saya',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _profileEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          actions: const [],
        ),
      );
    }
  }

  void _startPromoAutoScroll() {
    _promoAutoScrollTimer?.cancel();
    _promoAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_promoPageController.hasClients) return;
      final nextIndex = (_currentPromoIndex + 1) % _promoList.length;
      _promoPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 550),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  void _resetPromoAutoScroll() {
    _startPromoAutoScroll();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_flashSaleSeconds > 0) {
        setState(() {
          _flashSaleSeconds--;
        });
      }
    });
  }

  List<String> get _formattedCountdown {
    final h = (_flashSaleSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_flashSaleSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_flashSaleSeconds % 60).toString().padLeft(2, '0');
    return [h, m, s];
  }

  List<Map<String, dynamic>> get _promoList {
    final countdown = _formattedCountdown;
    final countdownStr = '${countdown[0]}:${countdown[1]}:${countdown[2]}';

    return [
      {
        'id': 'promo_flash',
        'tag': '⚡ MEGA FLASH SALE',
        'headline': 'Diskon s/d 70% + Extra Voucher',
        'sub': 'Super Sale • Ends in $countdownStr',
        'badge': 'DISKON 70%',
        'cta': 'SERBU SEKARANG',
        'hasCountdown': true,
        'voucherCode': 'TOKOFLASH70',
        'terms':
            'Diskon 70% khusus produk terdaftar Flash Sale. Berlaku hingga kuota harian habis. Tanpa min. transaksi.',
        'image':
            'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&auto=format&fit=crop&q=80',
        'gradient': [
          const Color(0xFFD32F2F),
          const Color(0xFFF44336),
          const Color(0xFFFF9800),
        ],
        'accentColor': const Color(0xFFFFD54F),
        'badgeBg': const Color(0xFFD32F2F),
      },
      {
        'id': 'promo_ongkir',
        'tag': '🚚 BEBAS ONGKIR EXTRA',
        'headline': 'Gratis Ongkir s/d Rp 50.000',
        'sub': 'Tanpa Minimum Transaksi • Seluruh Indonesia',
        'badge': 'MIN. RP 0',
        'cta': 'KLAIM VOUCHER',
        'hasCountdown': false,
        'voucherCode': 'FREEONGKIR50K',
        'terms':
            'Potongan ongkos kirim hingga Rp 50.000 untuk pengiriman Reguler dan Hemat ke seluruh Indonesia.',
        'image':
            'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800&auto=format&fit=crop&q=80',
        'gradient': [
          const Color(0xFF004D40),
          const Color(0xFF00796B),
          const Color(0xFF00BFA5),
        ],
        'accentColor': const Color(0xFFA7FFEB),
        'badgeBg': const Color(0xFF00796B),
      },
      {
        'id': 'promo_payday',
        'tag': '💎 GOPAY & QRIS SPECIAL',
        'headline': 'Cashback Extra 100% s/d Rp 100RB',
        'sub': 'Voucher Cashback Otomatis Terpasang Saat Checkout',
        'badge': 'CASHBACK 100%',
        'cta': 'AMBIL CASHBACK',
        'hasCountdown': false,
        'voucherCode': 'PAYDAYGOPAY',
        'terms':
            'Cashback 100% berupa Koin TokoKita hingga Rp 100.000 untuk transaksi dengan GoPay atau QRIS.',
        'image':
            'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800&auto=format&fit=crop&q=80',
        'gradient': [
          const Color(0xFF1A237E),
          const Color(0xFF3F51B5),
          const Color(0xFF7C4DFF),
        ],
        'accentColor': const Color(0xFFFFD700),
        'badgeBg': const Color(0xFF3F51B5),
      },
      {
        'id': 'promo_tech',
        'tag': '💻 TECH & GADGET FAIR',
        'headline': 'Gadget Flagship Cicilan 0%',
        'sub': 'Garansi Resmi 1 Tahun + Free Exclusive Sleeve',
        'badge': 'CICILAN 0%',
        'cta': 'CEK KATALOG',
        'hasCountdown': false,
        'voucherCode': 'TECHFAIR0',
        'terms':
            'Fasilitas cicilan 0% hingga 12 bulan menggunakan kartu kredit utama atau PayLater terpilih.',
        'image':
            'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=800&auto=format&fit=crop&q=80',
        'gradient': [
          const Color(0xFF0F2027),
          const Color(0xFF203A43),
          const Color(0xFF2C5364),
        ],
        'accentColor': const Color(0xFF80DEEA),
        'badgeBg': const Color(0xFF00ACC1),
      },
      {
        'id': 'promo_fashion',
        'tag': '✨ OFFICIAL STORE EXCLUSIVE',
        'headline': 'Buy 1 Get 1 Free + Gift Set',
        'sub': 'Koleksi Fashion & Beauty 100% Original',
        'badge': 'BUY 1 GET 1',
        'cta': 'BELANJA SEKARANG',
        'hasCountdown': false,
        'voucherCode': 'SUPERBRANDDEAL',
        'terms':
            'Gratis 1 produk tambahan berlabel B1G1 dan bonus Pouch Eksklusif TokoKita Official.',
        'image':
            'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&auto=format&fit=crop&q=80',
        'gradient': [
          const Color(0xFF880E4F),
          const Color(0xFFAD1457),
          const Color(0xFFD81B60),
        ],
        'accentColor': const Color(0xFFFF80AB),
        'badgeBg': const Color(0xFFC2185B),
      },
    ];
  }

  void _showPromoDetailSheet(Map<String, dynamic> promo) {
    HapticFeedback.lightImpact();
    final gradient = promo['gradient'] as List<Color>;
    final code = promo['voucherCode'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            promo['tag'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            promo['badge'] as String,
                            style: TextStyle(
                              color: promo['badgeBg'] as Color,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      promo['headline'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promo['sub'] as String,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Kode Voucher Promo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    BounceButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text('Kode voucher "$code" berhasil disalin!'),
                              ],
                            ),
                            backgroundColor: AppColors.stockAvailableText,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Salin Kode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Syarat & Ketentuan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                promo['terms'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: BounceButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Voucher "$code" terpasang otomatis!',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Klaim & Gunakan Voucher',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromoCarousel() {
    final promoList = _promoList;
    final countdown = _formattedCountdown;

    return Column(
      children: [
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _promoPageController,
            onPageChanged: (index) {
              setState(() => _currentPromoIndex = index);
              _resetPromoAutoScroll();
            },
            itemCount: promoList.length,
            itemBuilder: (context, index) {
              final promo = promoList[index];
              final gradient = promo['gradient'] as List<Color>;
              final hasCountdown = promo['hasCountdown'] as bool;
              final accentColor = promo['accentColor'] as Color;

              return BounceButton(
                onPressed: () => _showPromoDetailSheet(promo),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Image Background
                        Positioned.fill(
                          child: Image.network(
                            promo['image'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: gradient[0]),
                          ),
                        ),
                        // Professional Multi-Stop Gradient Overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  gradient[0].withValues(alpha: 0.95),
                                  gradient[1].withValues(alpha: 0.88),
                                  gradient[2].withValues(alpha: 0.65),
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Ambient Decorative Glow Shapes
                        Positioned(
                          right: -30,
                          top: -30,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 40,
                          bottom: -40,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        // Banner Content
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Bar: Glass Tag Chip & Page Counter
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      promo['tag'] as String,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${index + 1}/${promoList.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Middle Section: Headline & Live Countdown
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    promo['headline'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black38,
                                          offset: Offset(0, 1),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  if (hasCountdown)
                                    Row(
                                      children: [
                                        const Text(
                                          'Berakhir dalam  ',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        _buildTimerChip(countdown[0]),
                                        const Text(
                                          ' : ',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        _buildTimerChip(countdown[1]),
                                        const Text(
                                          ' : ',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        _buildTimerChip(countdown[2]),
                                      ],
                                    )
                                  else
                                    Text(
                                      promo['sub'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              // Bottom Section: Badge & CTA Button
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      promo['badge'] as String,
                                      style: TextStyle(
                                        color: promo['badgeBg'] as Color,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          promo['cta'] as String,
                                          style: TextStyle(
                                            color: promo['badgeBg'] as Color,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 12,
                                          color: promo['badgeBg'] as Color,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dynamic Glowing Indicator Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(promoList.length, (index) {
                  final isSelected = _currentPromoIndex == index;
                  return GestureDetector(
                    onTap: () {
                      _promoPageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isSelected ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: isSelected
                            ? LinearGradient(
                                colors: promoList[_currentPromoIndex]['gradient']
                                    as List<Color>,
                              )
                            : null,
                        color: isSelected ? null : AppColors.border,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (promoList[_currentPromoIndex]
                                          ['badgeBg'] as Color)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1.5),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimerChip(String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        val,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  // Widget Bar Kategori Seragam & Berkelas untuk Beranda, Favorit, & Keranjang
  // PRD section 4: Filter Kategori (ChoiceChip / FilterChip): Chip aktif menggunakan latar AppColors.accentSoft dengan teks tebal AppColors.accent. Chip non-aktif menggunakan latar AppColors.cardSurface dengan border AppColors.border.
  Widget _buildUnifiedCategoryBar(
    String selectedCategory,
    ValueChanged<String> onSelected,
  ) {
    final categoryItems = [
      {'name': 'Semua', 'icon': Icons.apps_rounded},
      {'name': 'Elektronik', 'icon': Icons.devices_rounded},
      {'name': 'Pakaian', 'icon': Icons.checkroom_rounded},
      {'name': 'Aksesori', 'icon': Icons.watch_rounded},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: categoryItems.map((item) {
          final name = item['name'] as String;
          final icon = item['icon'] as IconData;
          final isSelected =
              selectedCategory.toLowerCase() == name.toLowerCase();

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => onSelected(name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentSoft
                        : AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildTopBar(),
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildHomeView(),
          _buildFavoriteView(),
          _buildCartView(),
          _buildProfileView(),
        ],
      ),
      bottomNavigationBar: _buildCustomNavigationBar(),
    );
  }

  Widget _buildCustomNavigationBar() {
    final items = [
      {
        'icon': Icons.home_outlined,
        'activeIcon': Icons.home_rounded,
        'label': 'Beranda',
      },
      {
        'icon': Icons.favorite_border_rounded,
        'activeIcon': Icons.favorite_rounded,
        'label': 'Favorit',
      },
      {
        'icon': Icons.shopping_bag_outlined,
        'activeIcon': Icons.shopping_bag_rounded,
        'label': 'Keranjang',
      },
      {
        'icon': Icons.person_outline_rounded,
        'activeIcon': Icons.person_rounded,
        'label': 'Profil',
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        bottom: true,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = _currentNavIndex == index;
              const activeColor = AppColors.primary;
              const inactiveColor = AppColors.textSecondary;

              return Expanded(
                child: BounceButton(
                  scaleFactor: 0.90,
                  duration: const Duration(milliseconds: 100),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _currentNavIndex = index);
                  },
                  child: Container(
                    height: 58,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected
                              ? (item['activeIcon'] as IconData)
                              : (item['icon'] as IconData),
                          color: isSelected ? activeColor : inactiveColor,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            color: isSelected ? activeColor : inactiveColor,
                            fontSize: 10.5,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // Beranda View
  Widget _buildHomeView() {
    final sourceList = _selectedCategory == 'Semua' ? _shuffledProducts : products;
    final list = sourceList.where((p) {
      final matchCat =
          _selectedCategory == 'Semua' ||
          p.category.toLowerCase() == _selectedCategory.toLowerCase();
      
      final query = _searchQuery.trim().toLowerCase();
      bool matchSearch = true;
      if (query.isNotEmpty) {
        final searchTerms = query.split(RegExp(r'\s+'));
        final searchableText =
            '${p.name} ${p.category} ${p.description} ${p.detailDescription}'
                .toLowerCase();
        matchSearch = searchTerms.every((term) => searchableText.contains(term));
      }

      return matchCat && matchSearch;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Cari produk di TokoKita...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildPromoCarousel(),
            ],
          ),
        ),
        _buildUnifiedCategoryBar(_selectedCategory, (val) {
          setState(() => _selectedCategory = val);
        }),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    'Produk tidak ditemukan',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.74,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final product = list[index];
                    return ProductCardGrid(
                      product: product,
                      isFavorite: _isProductFavorite(product.id),
                      onFavoriteToggle: () => _toggleFavorite(product.id),
                      onAddToCart: () {
                        _addToCart(product.id, 1);
                        _showSnackBar('${product.name} ditambah ke keranjang');
                      },
                      onTap: () => _openProductDetail(product),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // FAVORIT VIEW: Desain Card Horizontal Kompak (Love di Kanan Atas, Cart di Kanan Bawah)
  Widget _buildFavoriteView() {
    final list = _favoriteProducts;

    final filteredFavs = list.where((p) {
      if (_selectedCategory == 'Semua') return true;
      return p.category.toLowerCase() ==
          _selectedCategory.toLowerCase();
    }).toList();

    return Column(
      children: [
        _buildUnifiedCategoryBar(_selectedCategory, (val) {
          setState(() => _selectedCategory = val);
        }),
        Expanded(
          child: filteredFavs.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada produk favorit di kategori ini',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredFavs.length,
                  itemBuilder: (context, index) {
                    final product = filteredFavs[index];
                    final isCartAdded = _cartAddedAnimIds.contains(product.id);
                    final isFav = _isProductFavorite(product.id);

                    return GestureDetector(
                      onTap: () => _openProductDetail(product),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10), // Padding proporsional 10px
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Gambar proporsional (72x72)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: Image.asset(
                                      product.imageAsset,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                            color: AppColors.background,
                                            child: const Icon(
                                              Icons.image_not_supported_outlined,
                                              size: 24,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 72, // Sama dengan tinggi gambar
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Kategori (atas) - dengan padding kanan agar tidak tertutup love icon
                                        Padding(
                                          padding: const EdgeInsets.only(right: 28),
                                          child: Text(
                                            product.category.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        // Nama Produk (tengah atas)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 28),
                                          child: Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                        // Harga (tengah bawah)
                                        Text(
                                          product.formattedPrice,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        // Rating (bawah) - dengan padding kanan agar tidak tertutup cart icon
                                        Padding(
                                          padding: const EdgeInsets.only(right: 32),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                size: 12,
                                                color: Colors.amber,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${product.rating}',
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '(${product.reviewCount})',
                                                style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Cart icon di kanan bawah
                            Positioned(
                              bottom: -6,
                              right: -4,
                              child: IconButton(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                style: IconButton.styleFrom(
                                  splashFactory: NoSplash.splashFactory,
                                  highlightColor: Colors.transparent,
                                ),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(scale: anim, child: child),
                                  child: Icon(
                                    isCartAdded
                                        ? Icons.check_rounded
                                        : Icons.add_shopping_cart_rounded,
                                    key: ValueKey<bool>(isCartAdded),
                                    color: isCartAdded
                                        ? Colors.green
                                        : AppColors.primary,
                                    size: 17,
                                  ),
                                ),
                                onPressed: () {
                                  _addToCart(product.id, 1);
                                  setState(() {
                                    _cartAddedAnimIds.add(product.id);
                                  });
                                  _showSnackBar(
                                      '${product.name} ditambah ke keranjang');
                                  Future.delayed(
                                      const Duration(milliseconds: 1500), () {
                                    if (mounted) {
                                      setState(() {
                                        _cartAddedAnimIds.remove(product.id);
                                      });
                                    }
                                  });
                                },
                                tooltip: 'Tambah ke Keranjang',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(2),
                              ),
                            ),
                            // Love icon di kanan atas
                            Positioned(
                              top: -4,
                              right: -4,
                              child: IconButton(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                style: IconButton.styleFrom(
                                  splashFactory: NoSplash.splashFactory,
                                  highlightColor: Colors.transparent,
                                ),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(scale: anim, child: child),
                                  child: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    key: ValueKey<bool>(isFav),
                                    color: AppColors.primary,
                                    size: 17,
                                  ),
                                ),
                                onPressed: () => _toggleFavorite(product.id),
                                tooltip: 'Hapus dari Favorit',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // KERANJANG VIEW: Desain Kategori Segmented Capsule yang Rapi & Berkelas dengan Checkbox
  Widget _buildCartView() {
    final list = _cartProducts;

    final filteredCart = list.where((entry) {
      if (_selectedCategory == 'Semua') return true;
      return entry.key.category.toLowerCase() ==
          _selectedCategory.toLowerCase();
    }).toList();

    final allFilteredIds = filteredCart.map((e) => e.key.id).toList();
    final isAllSelected =
        allFilteredIds.isNotEmpty &&
        allFilteredIds.every((id) => _cartItemChecked.contains(id));

    return Column(
      children: [
        _buildUnifiedCategoryBar(_selectedCategory, (val) {
          setState(() => _selectedCategory = val);
        }),
        if (filteredCart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.cardSurface,
            child: Row(
              children: [
                Checkbox(
                  value: isAllSelected,
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        for (final id in allFilteredIds) {
                          _cartItemChecked.add(id);
                        }
                      } else {
                        for (final id in allFilteredIds) {
                          _cartItemChecked.remove(id);
                        }
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pilih Semua Produk',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_cartItemChecked.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        for (final id in _cartItemChecked.toList()) {
                          _cartItemQuantities.remove(id);
                        }
                        _cartItemChecked.clear();
                      });
                      _showSnackBar('Produk terpilih berhasil dihapus');
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Hapus',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: filteredCart.isEmpty
              ? const Center(
                  child: Text(
                    'Keranjang belanja masih kosong untuk kategori ini',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredCart.length,
                  itemBuilder: (context, index) {
                    final entry = filteredCart[index];
                    final product = entry.key;
                    final qty = entry.value;
                    final isChecked = _cartItemChecked.contains(product.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: isChecked
                                ? Colors.black.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: isChecked ? 10 : 4,
                            offset: Offset(0, isChecked ? 4 : 2),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: Image.asset(
                                product.imageAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppColors.background,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 26,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  product.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12.5,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  product.formattedPrice,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _updateCartQuantity(product.id, -1),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          _updateCartQuantity(product.id, 1),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(Icons.add, size: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: isChecked,
                            activeColor: AppColors.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _cartItemChecked.add(product.id);
                                } else {
                                  _cartItemChecked.remove(product.id);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.cardSurface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Pembayaran',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    _formatRupiah(_cartTotalPrice),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              BounceButton(
                onPressed: _openCheckoutModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Checkout',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Profil View
  Widget _buildProfileView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.accentSoft,
                    child: Text(
                      _profileName.isEmpty
                          ? 'T'
                          : _profileName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _openProfilePhotoPicker,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profileEmail,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openAccountSettingsSheet,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(4),
                icon: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                tooltip: 'Edit Profil',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: const Text(
                  'Riwayat Pesanan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: _openOrderHistorySheet,
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: const Text(
                  'Alamat Pengiriman',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: _openAddressSheet,
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(
                  Icons.payment_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: const Text(
                  'Metode Pembayaran',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: _openPaymentMethodsSheet,
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(
                  Icons.headset_mic_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: const Text(
                  'Pusat Bantuan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: _openHelpCenterSheet,
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: const Text(
                  'Pengaturan Akun',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: _openAccountSettingsSheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BounceButton(
          onPressed: _confirmLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondaryMall.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: AppColors.secondaryMall,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Keluar Akun',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: AppColors.secondaryMall,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.cardSurface,
          title: const Text(
            'Keluar Akun',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari sesi akun TokoKita ini?',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Batal',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryMall,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Keluar',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatRupiah(int value) {
    final valStr = value.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valStr.replaceAllMapped(reg, (m) => '${m[1]}.')}';
  }
}
