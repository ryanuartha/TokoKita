import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/product_data.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/customer_address_service.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bounce_button.dart';
import '../widgets/checkout_sheet_components.dart';
import '../widgets/product_card_grid.dart';
import 'account_settings_screen.dart';
import 'address_management_screen.dart';
import 'help_center_screen.dart';
import 'notification_screen.dart';
import 'order_history_screen.dart';
import 'payment_gateway_screen.dart';
import 'payment_methods_screen.dart';
import 'map_address_picker_screen.dart';
import 'product_detail_screen.dart';
import 'welcome_screen.dart';

class ProductDashboard extends StatefulWidget {
  const ProductDashboard({
    super.key,
    required this.userName,
    this.userEmail = 'ravel@tokokita.id',
    this.isLoggedIn = false,
  });

  final String userName;
  final String userEmail;
  final bool isLoggedIn;

  @override
  State<ProductDashboard> createState() => _ProductDashboardState();
}

class _CartSelection {
  const _CartSelection({required this.productId, this.size, this.color});

  final String productId;
  final String? size;
  final String? color;

  String get storageKey => jsonEncode([productId, size, color]);

  static _CartSelection fromStorageKey(String key) {
    try {
      final decoded = jsonDecode(key);
      if (decoded is List &&
          decoded.length == 3 &&
          decoded[0] is String &&
          (decoded[1] == null || decoded[1] is String) &&
          (decoded[2] == null || decoded[2] is String)) {
        return _CartSelection(
          productId: decoded[0] as String,
          size: decoded[1] as String?,
          color: decoded[2] as String?,
        );
      }
    } on FormatException {
      // Older cart entries used the product ID as the key.
    }
    return _CartSelection(productId: key, size: 'M', color: 'Hitam');
  }
}

class _CartLine {
  const _CartLine({
    required this.selection,
    required this.product,
    required this.quantity,
  });

  final _CartSelection selection;
  final Product product;
  final int quantity;

  String get key => selection.storageKey;
}

class _ProductDashboardState extends State<ProductDashboard> {
  final PageController _promoPageController = PageController();
  int _currentPromoIndex = 0;
  Timer? _promoAutoScrollTimer;

  String _searchQuery = '';
  int _currentNavIndex = 0; // 0: Beranda, 1: Favorit, 2: Keranjang, 3: Profil
  final _searchController = TextEditingController();

  final Set<String> _favoriteProductIds = {};
  final Set<String> _pendingUnfavoriteIds = {};
  final Set<String> _pendingRemoveCartIds = {};
  final Set<String> _cartAddedAnimIds = {};
  final Map<String, int> _cartItemQuantities = {};
  final Set<String> _cartItemChecked = {};
  bool _hasUnreadNotifications = false;
  String _selectedPaymentMethod = 'QRIS';
  String _fulfillmentMethod = 'Pengiriman Kurir';
  String _selectedVoucherCode = 'Tanpa Voucher';
  String _selectedShippingAddress = '';
  double? _shippingLatitude;
  double? _shippingLongitude;

  // State Kategori Global Terpadu
  String _selectedCategory = 'Semua';

  late String _profileName;
  late String _profileEmail;
  String? _profileImagePath;
  late List<Product> _catalogProducts;
  late List<Product> _shuffledProducts;
  late bool _isLoggedIn;
  Map<String, int> _orderCounts = const {};
  static const int _guestCartVariantLimit = 50;
  static const String _guestCartKey = 'guest_cart_items';

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
    _profileName = widget.userName;
    _profileEmail = widget.userEmail;
    _loadProfileFromPrefs();
    if (AuthService.currentUser != null) {
      _loadPreferredShippingAddress();
    }
    _loadOrderCounts();
    _loadCartFromPrefs();
    _catalogProducts = List<Product>.from(products);
    _shuffledProducts = List<Product>.from(_catalogProducts)..shuffle();
    unawaited(_loadProductInventory());
    _startPromoAutoScroll();
  }

  Future<void> _loadProductInventory() async {
    try {
      final rows = await AuthService.client
          .from('products')
          .select('id, stock');
      final stocks = <String, int>{
        for (final row in rows) row['id'] as String: row['stock'] as int,
      };
      if (!mounted) return;
      final catalogProducts = products
          .where((product) => stocks.containsKey(product.id))
          .map((product) => product.copyWithStock(stocks[product.id]))
          .toList();
      setState(() {
        _catalogProducts = catalogProducts;
        _shuffledProducts = List<Product>.from(_catalogProducts)..shuffle();
      });
    } catch (error) {
      if (mounted) {
        _showSnackBar(
          'Stok produk terbaru belum dapat dimuat. Periksa koneksi.',
        );
      }
    }
  }

  Future<void> _loadProfileFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = AuthService.currentUser != null;
      _profileName = widget.userName;
      _profileEmail = widget.userEmail;
      _profileImagePath = _isLoggedIn
          ? prefs.getString('profile_image_path')
          : null;
    });
  }

  Future<void> _loadPreferredShippingAddress({bool force = false}) async {
    if (AuthService.currentUser == null ||
        (!force && _selectedShippingAddress.isNotEmpty)) {
      return;
    }
    try {
      final address = await CustomerAddressService.loadPreferredAddress();
      if (!mounted || address == null) return;
      setState(() {
        _selectedShippingAddress = address.address;
        _shippingLatitude = address.latitude;
        _shippingLongitude = address.longitude;
      });
    } catch (error) {
      if (mounted) {
        _showSnackBar('Alamat tersimpan belum dapat dimuat: $error');
      }
    }
  }

  Future<void> _loadOrderCounts() async {
    if (AuthService.currentUser == null) return;
    try {
      final orders = await OrderService.loadOrders();
      if (!mounted) return;
      setState(() {
        _orderCounts = {
          'waiting': orders
              .where((order) => order['status'] == 'Menunggu Bayar')
              .length,
          'processing': orders
              .where((order) => order['status'] == 'Perlu Diproses')
              .length,
          'shipping': orders
              .where(
                (order) =>
                    order['status'] == 'Dikirim' ||
                    order['status'] == 'Siap Diambil',
              )
              .length,
          'completed': orders
              .where((order) => order['status'] == 'Pesanan Selesai')
              .length,
        };
      });
    } catch (_) {
      if (mounted) {
        _showSnackBar('Ringkasan pesanan belum bisa dimuat. Coba lagi.');
      }
    }
  }

  Future<void> _loadCartFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCart = prefs.getString(_guestCartKey);
    if (rawCart == null || rawCart.isEmpty) return;

    try {
      final decoded = jsonDecode(rawCart);
      if (decoded is! Map) return;
      final loaded = <String, int>{};
      for (final entry in decoded.entries) {
        if (entry.key is String && entry.value is int && entry.value > 0) {
          final selection = _CartSelection.fromStorageKey(entry.key as String);
          loaded[selection.storageKey] = entry.value as int;
        }
      }
      if (!mounted) return;
      setState(() {
        _cartItemQuantities
          ..clear()
          ..addEntries(loaded.entries.take(_guestCartVariantLimit));
        _cartItemChecked
          ..clear()
          ..addAll(_cartItemQuantities.keys);
      });
    } catch (_) {}
  }

  Future<void> _saveCartToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestCartKey, jsonEncode(_cartItemQuantities));
  }

  Future<void> _openAuthGate({String? message}) async {
    if (_isLoggedIn) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Masuk untuk melanjutkan',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          content: Text(
            message ??
                'Masuk atau buat akun untuk menyimpan pesanan dan melihat riwayatnya.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const WelcomeScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Masuk atau Daftar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _promoAutoScrollTimer?.cancel();
    _promoPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalCartCount =>
      _cartItemQuantities.values.fold(0, (sum, count) => sum + count);

  List<Product> get _favoriteProducts {
    return _catalogProducts
        .where((product) => _favoriteProductIds.contains(product.id))
        .toList();
  }

  bool _isProductFavorite(String productId) {
    return _favoriteProductIds.contains(productId) &&
        !_pendingUnfavoriteIds.contains(productId);
  }

  List<_CartLine> get _cartProducts {
    final List<_CartLine> list = [];
    for (final entry in _cartItemQuantities.entries) {
      final selection = _CartSelection.fromStorageKey(entry.key);
      final match = _catalogProducts.where(
        (product) => product.id == selection.productId,
      );
      if (match.isNotEmpty && entry.value > 0) {
        list.add(
          _CartLine(
            selection: selection,
            product: match.first,
            quantity: entry.value,
          ),
        );
      }
    }
    return list;
  }

  int get _cartTotalPrice {
    int total = 0;
    for (final item in _cartProducts) {
      if (_cartItemChecked.contains(item.key)) {
        total += item.product.price * item.quantity;
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
      _showSnackBar('Produk dihapus dari favorit.');
    } else {
      setState(() {
        _favoriteProductIds.add(productId);
      });
      _showSnackBar('Produk ditambahkan ke favorit.');
    }
  }

  void _addToCart(
    String productId, {
    int quantity = 1,
    String? size = 'M',
    String? color = 'Hitam',
  }) {
    final selection = _CartSelection(
      productId: productId,
      size: size,
      color: color,
    );
    final key = selection.storageKey;
    if (_cartItemQuantities.length >= _guestCartVariantLimit &&
        !_cartItemQuantities.containsKey(key)) {
      _showSnackBar('Keranjang tanpa akun dibatasi hingga 50 varian produk.');
      return;
    }
    setState(() {
      _cartItemQuantities[key] = (_cartItemQuantities[key] ?? 0) + quantity;
      _cartItemChecked.add(key);
    });
    _saveCartToPrefs();
  }

  void _updateCartQuantity(String cartKey, int delta) {
    setState(() {
      final current = _cartItemQuantities[cartKey] ?? 0;
      final newQty = current + delta;
      if (newQty <= 0) {
        _removeCartItem(cartKey);
      } else {
        _cartItemQuantities[cartKey] = newQty;
      }
    });
    _saveCartToPrefs();
  }

  void _removeCartItem(String cartKey) {
    if (_cartItemQuantities.containsKey(cartKey)) {
      setState(() {
        _pendingRemoveCartIds.add(cartKey);
      });
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          setState(() {
            _cartItemQuantities.remove(cartKey);
            _pendingRemoveCartIds.remove(cartKey);
            _cartItemChecked.remove(cartKey);
          });
          _saveCartToPrefs();
        }
      });
    }
  }

  Future<void> _openProductDetail(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailScreen(
          product: product,
          isFavorite: _isProductFavorite(product.id),
          onFavoriteToggle: () => _toggleFavorite(product.id),
          onAddToCart: (qty, size, color) =>
              _addToCart(product.id, quantity: qty, size: size, color: color),
          onBuyNow: !_isLoggedIn
              ? () => _openAuthGate(
                  message: 'Masuk atau buat akun untuk melanjutkan pembelian.',
                )
              : null,
          userName: _profileName,
          userEmail: _profileEmail,
          initialShippingAddress: _selectedShippingAddress,
          initialShippingLatitude: _shippingLatitude,
          initialShippingLongitude: _shippingLongitude,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {});
      _loadPreferredShippingAddress(force: true);
      unawaited(_loadProductInventory());
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProfilePhotoPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubah foto profil',
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
                    'Ambil foto',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('profile_image_path', image.path);
                      setState(() {
                        _profileImagePath = image.path;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Foto profil berhasil diperbarui.'),
                          ),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Pilih dari galeri',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('profile_image_path', image.path);
                      setState(() {
                        _profileImagePath = image.path;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Foto profil berhasil diperbarui.'),
                          ),
                        );
                      }
                    }
                  },
                ),
                if (_profileImagePath != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.accent,
                    ),
                    title: const Text(
                      'Hapus foto profil',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.accent,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('profile_image_path');
                      setState(() {
                        _profileImagePath = null;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Foto profil dihapus.')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openNotificationSheet() {
    setState(() => _hasUnreadNotifications = false);
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const NotificationScreen()),
    );
  }

  void _openCheckoutModal() {
    if (_cartProducts.isEmpty) {
      _showSnackBar('Keranjang Anda masih kosong.');
      return;
    }

    Future<void> submitCartOrder(
      BuildContext sheetContext,
      List<_CartLine> checkedItems,
    ) async {
      final shippingAddress = _fulfillmentMethod == 'Ambil di Toko'
          ? ''
          : _selectedShippingAddress;
      if (_fulfillmentMethod == 'Pengiriman Kurir' &&
          (shippingAddress.trim().length < 8 ||
              _shippingLatitude == null ||
              _shippingLongitude == null)) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(
            content: Text(
              'Pilih titik peta dan isi alamat pengiriman terlebih dahulu.',
            ),
          ),
        );
        return;
      }
      Navigator.pop(sheetContext);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(width: 20),
              Expanded(child: Text('Sedang menyiapkan pesanan...')),
            ],
          ),
        ),
      );

      try {
        final createdOrder = await OrderService.createOrder(
          items: checkedItems
              .map(
                (item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                  'variant_size': item.selection.size,
                  'variant_color': item.selection.color,
                },
              )
              .toList(),
          paymentMethod: OrderService.paymentMethodForLabel(
            _selectedPaymentMethod,
          ),
          fulfillmentMethod: OrderService.fulfillmentMethodForLabel(
            _fulfillmentMethod,
          ),
          shippingAddress: shippingAddress,
          voucherCode: _selectedVoucherCode,
          shippingLatitude: _fulfillmentMethod == 'Ambil di Toko'
              ? null
              : _shippingLatitude,
          shippingLongitude: _fulfillmentMethod == 'Ambil di Toko'
              ? null
              : _shippingLongitude,
        );
        if (!mounted) return;
        Navigator.pop(context);

        setState(() {
          for (final id in _cartItemChecked.toList()) {
            _cartItemQuantities.remove(id);
          }
          _cartItemChecked.clear();
        });
        _saveCartToPrefs();
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => PaymentGatewayScreen(
              totalAmount: createdOrder.totalAmount,
              paymentMethod: _selectedPaymentMethod,
              userName: _profileName,
              userEmail: _profileEmail,
              shippingAddress: shippingAddress,
              orderId: createdOrder.id,
              displayId: createdOrder.displayId,
              paymentUrl: createdOrder.paymentUrl,
              expiresAt: createdOrder.expiresAt,
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        Navigator.pop(context);
        final message = error is StateError
            ? error.message.toString()
            : 'Pesanan belum berhasil dibuat. Periksa koneksi, lalu coba lagi.';
        _showSnackBar(message);
      }
    }

    if (_cartItemChecked.isEmpty || _cartTotalPrice == 0) {
      _showSnackBar('Pilih setidaknya satu produk untuk melanjutkan.');
      return;
    }
    if (!_isLoggedIn) {
      _openAuthGate(
        message:
            'Masuk atau buat akun untuk memilih cara menerima pesanan dan membayar.',
      );
      return;
    }

    final total = _cartTotalPrice;
    final checkedItems = _cartProducts
        .where((item) => _cartItemChecked.contains(item.key))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final canSubmit =
                _fulfillmentMethod == 'Ambil di Toko' ||
                (_selectedShippingAddress.trim().length >= 8 &&
                    _shippingLatitude != null &&
                    _shippingLongitude != null);
            final paymentOptions = [
              {
                'name': 'QRIS',
                'desc': 'Bayar dengan aplikasi yang mendukung QRIS',
              },
              {'name': 'GoPay', 'desc': 'Bayar dengan GoPay'},
              {
                'name': 'Transfer Bank BCA',
                'desc': 'Bayar melalui Virtual Account BCA',
              },
              if (_fulfillmentMethod != 'Ambil di Toko')
                {
                  'name': 'COD (Bayar di Tempat)',
                  'desc': 'Bayar tunai kepada kurir',
                },
              if (_fulfillmentMethod == 'Ambil di Toko')
                {
                  'name': 'Bayar di Toko (COD)',
                  'desc': 'Bayar tunai saat mengambil pesanan',
                },
              {'name': 'Kartu Kredit / Debit', 'desc': 'Visa atau Mastercard'},
            ];

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.86,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    children: [
                      CheckoutSheetHeader(onClose: () => Navigator.pop(ctx)),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cara menerima pesanan',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Pilih pengiriman ke alamat atau ambil sendiri di toko.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Kirim ke alamat'),
                                    selected:
                                        _fulfillmentMethod ==
                                        'Pengiriman Kurir',
                                    onSelected: (_) => setSheetState(() {
                                      _fulfillmentMethod = 'Pengiriman Kurir';
                                      if (_selectedPaymentMethod.contains(
                                        'Toko',
                                      )) {
                                        _selectedPaymentMethod = 'QRIS';
                                      }
                                    }),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Ambil di toko'),
                                    selected:
                                        _fulfillmentMethod == 'Ambil di Toko',
                                    onSelected: (_) => setSheetState(() {
                                      _fulfillmentMethod = 'Ambil di Toko';
                                      if (_selectedPaymentMethod.contains(
                                        'COD',
                                      )) {
                                        _selectedPaymentMethod =
                                            'Bayar di Toko (COD)';
                                      }
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CheckoutAddressCard(
                                recipientName: _profileName,
                                address: _selectedShippingAddress,
                                isStorePickup:
                                    _fulfillmentMethod == 'Ambil di Toko',
                                onChooseAddress: () async {
                                  final initialSelection =
                                      _shippingLatitude != null &&
                                          _shippingLongitude != null
                                      ? MapAddressSelection(
                                          address: _selectedShippingAddress,
                                          latitude: _shippingLatitude!,
                                          longitude: _shippingLongitude!,
                                        )
                                      : null;
                                  final selection = await showMapAddressPicker(
                                    ctx,
                                    initialSelection: initialSelection,
                                    initialAddress: _selectedShippingAddress,
                                  );
                                  if (!ctx.mounted || selection == null) {
                                    return;
                                  }
                                  if (AuthService.currentUser != null) {
                                    try {
                                      await CustomerAddressService.saveCheckoutAddress(
                                        recipientName: _profileName,
                                        address: selection.address,
                                        latitude: selection.latitude,
                                        longitude: selection.longitude,
                                      );
                                    } catch (error) {
                                      if (ctx.mounted) {
                                        _showSnackBar(
                                          'Alamat belum berhasil disimpan: $error',
                                        );
                                      }
                                      return;
                                    }
                                  }
                                  if (!ctx.mounted) return;
                                  setSheetState(() {
                                    _selectedShippingAddress =
                                        selection.address;
                                    _shippingLatitude = selection.latitude;
                                    _shippingLongitude = selection.longitude;
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Metode pembayaran',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Pilih cara pembayaran yang paling nyaman.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...paymentOptions.map((option) {
                                final name = option['name'] as String;
                                return CheckoutPaymentOption(
                                  name: name,
                                  description: option['desc'] as String,
                                  isSelected: _selectedPaymentMethod == name,
                                  onTap: () {
                                    setSheetState(() {
                                      _selectedPaymentMethod = name;
                                    });
                                  },
                                );
                              }),
                              const SizedBox(height: 12),
                              const Material(
                                color: AppColors.background,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.confirmation_number_outlined,
                                        color: AppColors.textSecondary,
                                        size: 18,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Belum ada voucher yang bisa digunakan.',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      CheckoutSheetFooter(
                        totalLabel: 'Total pembayaran',
                        totalAmount: _formatRupiah(total),
                        buttonLabel: _selectedPaymentMethod.contains('COD')
                            ? 'Buat pesanan'
                            : 'Lanjutkan ke pembayaran',
                        onPressed: canSubmit
                            ? () => submitCartOrder(ctx, checkedItems)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openOrderHistorySheet() {
    if (!_isLoggedIn) {
      _openAuthGate(
        message:
            'Masuk atau buat akun untuk melihat pesanan dan status pengirimannya.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const OrderHistoryScreen()),
    );
  }

  Future<void> _openAddressSheet() async {
    if (!_isLoggedIn) {
      _openAuthGate(
        message: 'Masuk atau buat akun untuk mengelola alamat pengiriman.',
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const AddressManagementScreen(),
      ),
    );
    if (mounted) _loadPreferredShippingAddress(force: true);
  }

  void _openPaymentMethodsSheet() {
    if (!_isLoggedIn) {
      _openAuthGate(
        message: 'Masuk atau buat akun untuk mengelola metode pembayaran.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const PaymentMethodsScreen(),
      ),
    );
  }

  void _openHelpCenterSheet() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => HelpCenterScreen(
          isLoggedIn: _isLoggedIn,
          onSignInRequired: () => _openAuthGate(
            message: 'Masuk atau buat akun untuk menghubungi admin toko.',
          ),
        ),
      ),
    );
  }

  void _openAccountSettingsSheet() {
    if (!_isLoggedIn) {
      _openAuthGate(
        message: 'Masuk atau buat akun untuk mengelola profil Anda.',
      );
      return;
    }
    Navigator.push<AuthenticatedProfile>(
      context,
      MaterialPageRoute<AuthenticatedProfile>(
        builder: (context) => const AccountSettingsScreen(),
      ),
    ).then((profile) {
      if (profile != null && mounted) {
        setState(() {
          _profileName = profile.fullName;
          _profileEmail = profile.email;
        });
      } else {
        _loadProfileFromPrefs();
      }
    });
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
                      'Temukan kebutuhan Anda di TokoKita.',
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
    if (_promoList.length < 2) return;
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

  List<Map<String, dynamic>> get _promoList => [
    {
      'id': 'promo_unavailable',
      'tag': 'INFORMASI',
      'headline': 'Belum ada promo saat ini',
      'sub': 'Promo yang bisa digunakan akan muncul di sini.',
      'badge': 'Belum tersedia',
      'cta': 'Info promo',
      'voucherCode': '',
      'terms': 'Saat ini belum ada promo yang dapat digunakan.',
      'isActive': false,
      'image':
          'https://images.unsplash.com/photo-1607083206869-4c7672e72a8a?w=1200&auto=format&fit=crop&q=80',
      'gradient': [const Color(0xFF334155), const Color(0xFF475569)],
      'accentColor': const Color(0xFFE2E8F0),
      'badgeBg': const Color(0xFF475569),
    },
  ];

  void _showPromoDetailSheet(Map<String, dynamic> promo) {
    if (promo['isActive'] != true) {
      _showSnackBar('Belum ada promo yang bisa digunakan saat ini.');
      return;
    }

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildPromoDetailSheetContent(ctx, promo),
    );
  }

  Widget _buildPromoDetailSheetContent(
    BuildContext ctx,
    Map<String, dynamic> promo,
  ) {
    final gradient = promo['gradient'] as List<Color>;
    final code = promo['voucherCode'] as String;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: SingleChildScrollView(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                        Navigator.pop(ctx);
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
                                Text('Kode voucher "$code" berhasil disalin.'),
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
                    setState(() {
                      _selectedVoucherCode = 'Tanpa Voucher';
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Voucher ini belum bisa digunakan. Pilih voucher yang tersedia saat checkout.',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
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
                      'Lihat voucher',
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
        ),
      ),
    );
  }

  Widget _buildPromoCarousel() {
    final promoList = _promoList;

    return Column(
      children: [
        SizedBox(
          height: 156,
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
              final accentColor = promo['accentColor'] as Color;

              return BounceButton(
                onPressed: promo['isActive'] == true
                    ? () => _showPromoDetailSheet(promo)
                    : null,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Real Photo Image Background
                        Positioned.fill(
                          child: Image.network(
                            promo['image'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: gradient[0]),
                          ),
                        ),
                        // Clean Professional Vignette Scrim:
                        // Deep dark tone on left for 100% text readability, fading to transparent on right
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.88),
                                  Colors.black.withValues(alpha: 0.65),
                                  Colors.black.withValues(alpha: 0.20),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.45, 0.75, 1.0],
                              ),
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
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      promo['tag'] as String,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
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
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
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
                                          color: Colors.black.withValues(
                                            alpha: 0.12,
                                          ),
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
                                  if (promo['isActive'] == true) ...[
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
                                            color: Colors.black.withValues(
                                              alpha: 0.15,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
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
        // Clean Indicator Dots
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
                      width: isSelected ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
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
        'icon': Icons.shopping_cart_outlined,
        'activeIcon': Icons.shopping_cart_rounded,
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
                    if (index == 3 && !_isLoggedIn) {
                      _openAuthGate(
                        message:
                            'Masuk atau daftar untuk membuka Profil dan mengelola akun TokoKita.',
                      );
                      return;
                    }
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

  Widget _buildTrendingChip(String keyword) {
    return GestureDetector(
      onTap: () {
        _searchController.text = keyword;
        setState(() => _searchQuery = keyword);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          keyword,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Beranda View
  Widget _buildHomeView() {
    final sourceList = _selectedCategory == 'Semua'
        ? _shuffledProducts
        : _catalogProducts;
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
        matchSearch = searchTerms.every(
          (term) => searchableText.contains(term),
        );
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
                  hintText: 'Cari produk',
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    const Text(
                      'Banyak dicari: ',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildTrendingChip('Smartphone'),
                    _buildTrendingChip('Hoodie'),
                    _buildTrendingChip('Smartwatch'),
                    _buildTrendingChip('Headphone'),
                    _buildTrendingChip('Kaos'),
                  ],
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
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await _loadProductInventory();
              if (!mounted) return;
              setState(() {
                _shuffledProducts.shuffle();
              });
            },
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'Produk tidak ditemukan. Coba kata kunci lain.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                          _addToCart(product.id, quantity: 1);
                          _showSnackBar(
                            '${product.name} ditambah ke keranjang',
                          );
                        },
                        onTap: () => _openProductDetail(product),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // FAVORIT VIEW: Desain Enterprise Global (Kartu Bersih, Badge Rating & Quick Add)
  Widget _buildFavoriteView() {
    final filteredFavs = _favoriteProducts;

    return Column(
      children: [
        Expanded(
          child: filteredFavs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Belum ada produk favorit',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: AppColors.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tekan ikon hati pada produk untuk menyimpannya di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        BounceButton(
                          onPressed: () => setState(() => _currentNavIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Jelajahi produk',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
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
                                          color: AppColors.textSecondary,
                                        ),
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
                                    product.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    product.name,
                                    maxLines: 1,
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
                                    product.formattedPrice,
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
                            Column(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  onPressed: () => _toggleFavorite(product.id),
                                  tooltip: 'Hapus dari Favorit',
                                ),
                                IconButton(
                                  icon: Icon(
                                    isCartAdded
                                        ? Icons.check_circle_rounded
                                        : Icons.add_shopping_cart_rounded,
                                    color: isCartAdded
                                        ? Colors.green
                                        : AppColors.primary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _addToCart(product.id, quantity: 1);
                                    setState(() {
                                      _cartAddedAnimIds.add(product.id);
                                    });
                                    _showSnackBar(
                                      '${product.name} ditambahkan ke keranjang.',
                                    );
                                    Future.delayed(
                                      const Duration(milliseconds: 1500),
                                      () {
                                        if (mounted) {
                                          setState(() {
                                            _cartAddedAnimIds.remove(
                                              product.id,
                                            );
                                          });
                                        }
                                      },
                                    );
                                  },
                                  tooltip: 'Tambah ke Keranjang',
                                ),
                              ],
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

  // KERANJANG VIEW: Desain Enterprise Global (Store Header, Stepper Kapsul & Bar Total Mengapung)
  Widget _buildCartView() {
    final filteredCart = _cartProducts;

    final allFilteredIds = filteredCart.map((item) => item.key).toList();
    final isAllSelected =
        allFilteredIds.isNotEmpty &&
        allFilteredIds.every((id) => _cartItemChecked.contains(id));

    return Column(
      children: [
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
                Text(
                  'Pilih semua (${allFilteredIds.length})',
                  style: const TextStyle(
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
                      _saveCartToPrefs();
                      _showSnackBar('Produk terpilih dihapus dari keranjang.');
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
                          'Hapus pilihan',
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Keranjang Anda masih kosong',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: AppColors.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Temukan produk yang Anda butuhkan, lalu tambahkan ke keranjang.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        BounceButton(
                          onPressed: () => setState(() => _currentNavIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Lihat produk',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredCart.length,
                  itemBuilder: (context, index) {
                    final entry = filteredCart[index];
                    final product = entry.product;
                    final qty = entry.quantity;
                    final isChecked = _cartItemChecked.contains(entry.key);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: isChecked
                                ? Colors.black.withAlpha(12)
                                : Colors.black.withAlpha(4),
                            blurRadius: isChecked ? 10 : 4,
                            offset: Offset(0, isChecked ? 4 : 2),
                          ),
                        ],
                        border: Border.all(
                          color: isChecked
                              ? AppColors.primary.withAlpha(120)
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: isChecked,
                            activeColor: AppColors.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _cartItemChecked.add(entry.key);
                                } else {
                                  _cartItemChecked.remove(entry.key);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 76,
                              height: 76,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (entry.selection.size != null ||
                                    entry.selection.color != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      if (entry.selection.size != null)
                                        'Ukuran ${entry.selection.size}',
                                      if (entry.selection.color != null)
                                        entry.selection.color!,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  product.formattedPrice,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _updateCartQuantity(
                                              entry.key,
                                              -1,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              child: const Icon(
                                                Icons.remove,
                                                size: 14,
                                                color: AppColors.textPrimary,
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
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => _updateCartQuantity(
                                              entry.key,
                                              1,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
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
                    );
                  },
                ),
        ),
        if (filteredCart.isNotEmpty)
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
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                BounceButton(
                  onPressed: _openCheckoutModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(76),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Checkout (${_cartItemChecked.length})',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
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

  // PROFIL VIEW: Desain Enterprise Global (Hero Member Card, Dynamic Order Status Bar, Grouped Options)
  Widget _buildProfileView() {
    final orderStatuses = [
      {
        'label': 'Belum Bayar',
        'icon': Icons.account_balance_wallet_outlined,
        'filterKey': 'Belum Bayar',
        'count': _orderCounts['waiting'] ?? 0,
      },
      {
        'label': 'Dikemas',
        'icon': Icons.inventory_2_outlined,
        'filterKey': 'Dikemas',
        'count': _orderCounts['processing'] ?? 0,
      },
      {
        'label': 'Dikirim',
        'icon': Icons.local_shipping_outlined,
        'filterKey': 'Dikirim',
        'count': _orderCounts['shipping'] ?? 0,
      },
      {
        'label': 'Selesai',
        'icon': Icons.rate_review_outlined,
        'filterKey': 'Selesai',
        'count': _orderCounts['completed'] ?? 0,
      },
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Hero User Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.accentSoft,
                    backgroundImage:
                        _profileImagePath != null &&
                            File(_profileImagePath!).existsSync()
                        ? FileImage(File(_profileImagePath!))
                        : null,
                    child:
                        _profileImagePath == null ||
                            !File(_profileImagePath!).existsSync()
                        ? Text(
                            _profileName.isEmpty
                                ? 'T'
                                : _profileName[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _openProfilePhotoPicker,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profileEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.primary,
                            size: 13,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Akun TokoKita',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openAccountSettingsSheet,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                tooltip: 'Edit Profil',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Order Status Quick Shortcuts Bar (Shopee / Tokopedia Style)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pesanan Saya',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openOrderHistorySheet,
                    child: const Row(
                      children: [
                        Text(
                          'Lihat Riwayat',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: orderStatuses.map((st) {
                  final count = st['count'] as int;
                  final filterKey = st['filterKey'] as String;

                  return BounceButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              OrderHistoryScreen(initialFilter: filterKey),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              st['icon'] as IconData,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            if (count > 0)
                              Positioned(
                                right: -6,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.secondaryMall,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 15,
                                    minHeight: 15,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          st['label'] as String,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Grouped Options: Akun & Keamanan
        Material(
          color: AppColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  'Akun & Keamanan',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
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
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
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
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: _openPaymentMethodsSheet,
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
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: _openAccountSettingsSheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Grouped Options: Bantuan & Layanan
        Material(
          color: AppColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  'Bantuan & Layanan',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: const Text(
                  'Notifikasi & Info',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: _openNotificationSheet,
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
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: _openHelpCenterSheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 5. Logout Button
        BounceButton(
          onPressed: _confirmLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondaryMall.withAlpha(100),
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
                  'Keluar',
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
        const SizedBox(height: 16),
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
            'Keluar dari akun',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Anda yakin ingin keluar dari akun?',
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
              onPressed: () async {
                Navigator.pop(dialogContext);
                final prefs = await SharedPreferences.getInstance();
                if (AuthService.currentUser != null) {
                  await AuthService.client.auth.signOut();
                }
                await prefs.remove('is_logged_in');
                await prefs.remove('user_role');
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const ProductDashboard(
                      userName: 'Pengguna TokoKita',
                      userEmail: 'pengguna@tokokita.id',
                      isLoggedIn: false,
                    ),
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
