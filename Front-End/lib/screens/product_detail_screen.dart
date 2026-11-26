import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/customer_address_service.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bounce_button.dart';
import '../widgets/checkout_sheet_components.dart';
import '../widgets/strikethrough_price.dart';
import 'map_address_picker_screen.dart';
import 'payment_gateway_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onAddToCart,
    this.onBuyNow,
    required this.userName,
    required this.userEmail,
    this.initialShippingAddress = '',
    this.initialShippingLatitude,
    this.initialShippingLongitude,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final void Function(int quantity, String size, String color) onAddToCart;
  final VoidCallback? onBuyNow;
  final String userName;
  final String userEmail;
  final String initialShippingAddress;
  final double? initialShippingLatitude;
  final double? initialShippingLongitude;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  String _selectedSize = 'M';
  String _selectedColor = 'Hitam';
  String _selectedPaymentMethod = 'QRIS';
  late bool _isFavorite;
  bool _isFollowingStore = false;
  bool _isAddedToCart = false;
  late String _shippingAddress;
  double? _shippingLatitude;
  double? _shippingLongitude;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _shippingAddress = widget.initialShippingAddress;
    _shippingLatitude = widget.initialShippingLatitude;
    _shippingLongitude = widget.initialShippingLongitude;
    if (_shippingAddress.isEmpty) {
      unawaited(_loadPreferredShippingAddress());
    }
  }

  Future<void> _loadPreferredShippingAddress() async {
    if (AuthService.currentUser == null) return;
    try {
      final address = await CustomerAddressService.loadPreferredAddress();
      if (!mounted || address == null) return;
      setState(() {
        _shippingAddress = address.address;
        _shippingLatitude = address.latitude;
        _shippingLongitude = address.longitude;
      });
    } catch (error) {
      if (mounted) {
        _showSnackBar('Alamat tersimpan belum dapat dimuat: $error');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createOrder(BuildContext sheetContext) async {
    if (_shippingAddress.trim().length < 8 ||
        _shippingLatitude == null ||
        _shippingLongitude == null) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih titik peta dan isi alamat pengiriman terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    final product = widget.product;
    final shippingAddress = _shippingAddress;
    Navigator.pop(sheetContext);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
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
      final order = await OrderService.createOrder(
        items: [
          {
            'product_id': product.id,
            'quantity': _quantity,
            'variant_size': _selectedSize,
            'variant_color': _selectedColor,
          },
        ],
        paymentMethod: OrderService.paymentMethodForLabel(
          _selectedPaymentMethod,
        ),
        fulfillmentMethod: 'courier',
        shippingAddress: shippingAddress,
        voucherCode: '',
        shippingLatitude: _shippingLatitude,
        shippingLongitude: _shippingLongitude,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PaymentGatewayScreen(
            totalAmount: order.totalAmount,
            paymentMethod: _selectedPaymentMethod,
            userName: widget.userName,
            userEmail: widget.userEmail,
            shippingAddress: shippingAddress,
            orderId: order.id,
            displayId: order.displayId,
            paymentUrl: order.paymentUrl,
            expiresAt: order.expiresAt,
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

  void _handleFavoriteTap() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    widget.onFavoriteToggle();
    _showSnackBar(
      _isFavorite
          ? 'Produk ditambahkan ke favorit.'
          : 'Produk dihapus dari favorit.',
    );
  }

  void _handleAddToCartTap() {
    if (widget.product.stock == 0) {
      _showSnackBar('Stok produk sedang habis.');
      return;
    }
    widget.onAddToCart(_quantity, _selectedSize, _selectedColor);
    setState(() => _isAddedToCart = true);
    _showSnackBar(
      '$_quantity x ${widget.product.name} ($_selectedSize, $_selectedColor) '
      'dimasukkan ke keranjang',
    );
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _isAddedToCart = false);
    });
  }

  void _openCheckoutSheet() {
    if (widget.product.stock == 0) {
      _showSnackBar('Stok produk sedang habis.');
      return;
    }
    if (widget.onBuyNow != null) {
      widget.onBuyNow!();
      return;
    }
    final product = widget.product;
    final totalPrice = product.price * _quantity;

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
                _shippingAddress.trim().length >= 8 &&
                _shippingLatitude != null &&
                _shippingLongitude != null;
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
              {
                'name': 'COD (Bayar di Tempat)',
                'desc': 'Bayar tunai kepada kurir',
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
                              CheckoutAddressCard(
                                recipientName: widget.userName,
                                address: _shippingAddress,
                                isStorePickup: false,
                                onChooseAddress: () async {
                                  final initialSelection =
                                      _shippingLatitude != null &&
                                          _shippingLongitude != null
                                      ? MapAddressSelection(
                                          address: _shippingAddress,
                                          latitude: _shippingLatitude!,
                                          longitude: _shippingLongitude!,
                                        )
                                      : null;
                                  final selection = await showMapAddressPicker(
                                    ctx,
                                    initialSelection: initialSelection,
                                    initialAddress: _shippingAddress,
                                  );
                                  if (!ctx.mounted || selection == null) {
                                    return;
                                  }
                                  if (AuthService.currentUser != null) {
                                    try {
                                      await CustomerAddressService.saveCheckoutAddress(
                                        recipientName: widget.userName,
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
                                    _shippingAddress = selection.address;
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
                            ],
                          ),
                        ),
                      ),
                      CheckoutSheetFooter(
                        totalLabel: 'Total pembayaran',
                        totalAmount: _formatRupiah(totalPrice),
                        buttonLabel: _selectedPaymentMethod.contains('COD')
                            ? 'Buat pesanan'
                            : 'Lanjutkan ke pembayaran',
                        onPressed: canSubmit ? () => _createOrder(ctx) : null,
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

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final stock = product.stock;
    final stockColor = stock == null
        ? AppColors.textSecondary
        : stock == 0
        ? AppColors.stockEmptyText
        : stock <= 5
        ? AppColors.stockLowText
        : AppColors.stockAvailableText;
    final stockBackground = stock == null
        ? AppColors.background
        : stock == 0
        ? AppColors.stockEmptyBg
        : stock <= 5
        ? AppColors.stockLowBg
        : AppColors.stockAvailableBg;
    final isOutOfStock = stock == 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Rincian Produk',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_outlined,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Bagikan produk',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.cardSurface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bagikan Produk',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildShareOption(
                            Icons.chat_bubble_rounded,
                            'WhatsApp',
                            Colors.green,
                            () => _shareViaWhatsApp(ctx),
                          ),
                          _buildShareOption(
                            Icons.copy_rounded,
                            'Salin Info',
                            AppColors.primary,
                            () => _copyProductInfo(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey<bool>(_isFavorite),
                color: _isFavorite ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            tooltip: _isFavorite
                ? 'Hapus dari favorit'
                : 'Tambahkan ke favorit',
            onPressed: _handleFavoriteTap,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: AppColors.cardSurface,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.asset(
                  product.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.background,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_rounded,
                      color: AppColors.textSecondary,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Container(
              color: AppColors.cardSurface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: stockBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: stockColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              stock == null
                                  ? 'Stok dimuat'
                                  : stock == 0
                                  ? 'Stok habis'
                                  : 'Tersedia $stock unit',
                              style: TextStyle(
                                color: stockColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        product.formattedPrice,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (product.originalPrice != null &&
                          product.originalPrice! > product.price)
                        StrikethroughPrice(
                          text: product.formattedOriginalPrice!,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      if (product.discountPercentage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Hemat ${product.discountPercentage}%',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: AppColors.starYellow,
                        size: 15,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '0.0',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '|',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Belum terjual',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              color: AppColors.cardSurface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Ukuran',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Dipilih: $_selectedSize',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: product.availableSizes.map((size) {
                      return _buildVariantChip(
                        label: size,
                        isSelected: _selectedSize == size,
                        onTap: () => setState(() => _selectedSize = size),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Warna',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Dipilih: $_selectedColor',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: product.availableColors.map((color) {
                      return _buildVariantChip(
                        label: color,
                        isSelected: _selectedColor == color,
                        onTap: () => setState(() => _selectedColor = color),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              color: AppColors.cardSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'TokoKita Official',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Tooltip(
                              message: 'Toko resmi terverifikasi',
                              child: Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textSecondary,
                              size: 13,
                            ),
                            SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                'Yogyakarta',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() => _isFollowingStore = !_isFollowingStore);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(58, 36),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(_isFollowingStore ? 'Mengikuti' : '+ Ikuti'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              color: AppColors.cardSurface,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.stockAvailableBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_return_outlined,
                      color: AppColors.accentTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kebijakan pengembalian',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ajukan melalui Pusat Bantuan jika barang diterima '
                          'rusak atau tidak sesuai. Pengajuan akan ditinjau '
                          'berdasarkan kondisi barang dan ketentuan toko.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              color: AppColors.cardSurface,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.stockAvailableBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.accentTeal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengiriman',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Biaya pengiriman saat ini Rp0. Alamat dipilih saat checkout.',
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
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              color: AppColors.cardSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Jumlah',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.remove, size: 16),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: stock != null && _quantity >= stock
                            ? null
                            : () => setState(() => _quantity++),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: stock != null && _quantity >= stock
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              color: AppColors.cardSurface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deskripsi Produk',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    product.detailDescription,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              color: AppColors.cardSurface,
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ulasan',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Belum ada ulasan untuk produk ini.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: BounceButton(
                    onPressed: isOutOfStock ? null : _handleAddToCartTap,
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOutOfStock
                              ? AppColors.border
                              : _isAddedToCart
                              ? AppColors.stockAvailableText
                              : AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isAddedToCart
                                ? Icons.check_circle_rounded
                                : Icons.add_shopping_cart_rounded,
                            size: 18,
                            color: isOutOfStock
                                ? AppColors.textMuted
                                : _isAddedToCart
                                ? AppColors.stockAvailableText
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _isAddedToCart ? 'Tersimpan' : '+ Keranjang',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: isOutOfStock
                                    ? AppColors.textMuted
                                    : _isAddedToCart
                                    ? AppColors.stockAvailableText
                                    : AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BounceButton(
                    onPressed: isOutOfStock ? null : _openCheckoutSheet,
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? AppColors.stockEmptyBg
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isOutOfStock
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isOutOfStock ? 'Stok habis' : 'Beli Sekarang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: isOutOfStock
                              ? AppColors.stockEmptyText
                              : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentSoft : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String get _productShareText =>
      '${widget.product.name} - ${widget.product.formattedPrice}\nTokoKita';

  Future<void> _shareViaWhatsApp(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    try {
      final opened = await launchUrl(
        Uri.https('wa.me', '/', {'text': _productShareText}),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showSnackBar('WhatsApp tidak dapat dibuka di perangkat ini.');
      }
    } catch (error) {
      if (mounted) _showSnackBar('WhatsApp tidak dapat dibuka: $error');
    }
  }

  Future<void> _copyProductInfo(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    try {
      await Clipboard.setData(ClipboardData(text: _productShareText));
      if (mounted) _showSnackBar('Info produk berhasil disalin.');
    } catch (error) {
      if (mounted) _showSnackBar('Info produk belum berhasil disalin: $error');
    }
  }

  static String _formatRupiah(int value) {
    final valStr = value.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valStr.replaceAllMapped(reg, (m) => '${m[1]}.')}';
  }
}
