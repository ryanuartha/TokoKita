import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _productsFuture;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _productsFuture = _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadProducts() async {
    final rows = await AuthService.client
        .from('products')
        .select('id, name, category, price, stock, active, image_asset')
        .order('category')
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _refreshProducts() async {
    final future = _loadProducts();
    setState(() => _productsFuture = future);
    await future;
  }

  Future<void> _editStock(Map<String, dynamic> product) async {
    final updatedStock = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _StockEditorDialog(
        productName: product['name'] as String,
        initialStock: product['stock'] as int,
      ),
    );
    if (!mounted || updatedStock == null) return;

    try {
      final result = await AuthService.client
          .from('products')
          .update({
            'stock': updatedStock,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', product['id'] as String)
          .select('id')
          .maybeSingle();
      if (result == null) {
        throw StateError('Produk tidak ditemukan atau Anda tidak berwenang.');
      }
      await _refreshProducts();
      if (mounted) _showMessage('Stok berhasil diperbarui.');
    } catch (error) {
      if (mounted) {
        _showMessage('Stok belum berhasil diperbarui: ${_errorMessage(error)}');
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    return 'Pastikan migration inventaris sudah diterapkan dan akun admin '
        'memiliki izin mengubah stok.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatRupiah(int value) {
    final digits = value.toString();
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${digits.replaceAllMapped(pattern, (match) => '${match[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Produk & inventaris',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Pantau ketersediaan produk dan perbarui stok.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau kode produk',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              if (snapshot.hasError) {
                return _buildErrorState();
              }

              final products = snapshot.data ?? const [];
              final categories = <String>[
                'Semua',
                ...products
                    .map((product) => product['category'] as String)
                    .toSet()
                    .toList()
                  ..sort(),
              ];
              final filteredProducts = products.where((product) {
                final matchesCategory =
                    _selectedCategory == 'Semua' ||
                    product['category'] == _selectedCategory;
                final searchText = '${product['id']} ${product['name']}'
                    .toLowerCase();
                return matchesCategory && searchText.contains(_searchQuery);
              }).toList();
              final lowStockCount = products
                  .where(
                    (product) =>
                        (product['stock'] as int) <= 5 &&
                        (product['active'] as bool),
                  )
                  .length;

              return Column(
                children: [
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          '${filteredProducts.length} produk',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (lowStockCount > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 15,
                                color: Color(0xFFB7791F),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$lowStockCount stok rendah',
                                style: const TextStyle(
                                  color: Color(0xFF986515),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        IconButton(
                          tooltip: 'Muat ulang produk',
                          visualDensity: VisualDensity.compact,
                          onPressed: _refreshProducts,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? _buildNoResults()
                        : RefreshIndicator(
                            onRefresh: _refreshProducts,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: filteredProducts.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _buildProductCard(filteredProducts[index]),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final stock = product['stock'] as int;
    final isActive = product['active'] as bool;
    final stockColor = !isActive
        ? AppColors.textMuted
        : stock == 0
        ? AppColors.coralRed
        : stock <= 5
        ? const Color(0xFFB7791F)
        : AppColors.accentTeal;
    final stockLabel = !isActive
        ? 'Nonaktif'
        : stock == 0
        ? 'Habis'
        : stock <= 5
        ? 'Stok rendah'
        : 'Tersedia';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              product['image_asset'] as String,
              width: 62,
              height: 62,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 62,
                height: 62,
                color: AppColors.background,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product['id']} • ${_formatRupiah(product['price'] as int)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: stockColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$stock unit • $stockLabel',
                      style: TextStyle(
                        color: stockColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ubah stok',
            onPressed: () => _editStock(product),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentSoft,
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 10),
            Text(
              'Produk tidak ditemukan',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Coba kata kunci atau kategori lain.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'Data produk belum dapat dimuat',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Periksa koneksi dan izin akun admin, lalu coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _productsFuture = _loadProducts()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockEditorDialog extends StatefulWidget {
  const _StockEditorDialog({
    required this.productName,
    required this.initialStock,
  });

  final String productName;
  final int initialStock;

  @override
  State<_StockEditorDialog> createState() => _StockEditorDialogState();
}

class _StockEditorDialogState extends State<_StockEditorDialog> {
  late final TextEditingController _stockController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(text: '${widget.initialStock}');
  }

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Perbarui stok'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.productName,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stockController,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              if (_validationMessage != null) {
                setState(() => _validationMessage = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Jumlah stok',
              suffixText: 'unit',
              errorText: _validationMessage,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final stock = int.tryParse(_stockController.text.trim());
            if (stock == null || stock < 0) {
              setState(
                () => _validationMessage = 'Masukkan jumlah unit 0 atau lebih.',
              );
              return;
            }
            Navigator.pop(context, stock);
          },
          child: const Text('Simpan stok'),
        ),
      ],
    );
  }
}
