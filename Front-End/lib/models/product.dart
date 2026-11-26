class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.imageAsset,
    required this.description,
    required this.detailDescription,
    required this.price,
    this.originalPrice,
    this.rating = 4.8,
    this.reviewCount = 50,
    this.soldCount = 100,
    this.availableSizes = const ['S', 'M', 'L', 'XL'],
    this.availableColors = const ['Hitam', 'Putih', 'Navy', 'Abu-abu'],
    this.badge,
    this.isFavorite = false,
    this.stock,
  });

  final String id;
  final String name;
  final String category;
  final String imageAsset;
  final String description;
  final String detailDescription;
  final int price;
  final int? originalPrice;
  final double rating;
  final int reviewCount;
  final int soldCount;
  final List<String> availableSizes;
  final List<String> availableColors;
  final String? badge;
  final bool isFavorite;
  final int? stock;

  Product copyWithStock(int? stock) => Product(
    id: id,
    name: name,
    category: category,
    imageAsset: imageAsset,
    description: description,
    detailDescription: detailDescription,
    price: price,
    originalPrice: originalPrice,
    rating: rating,
    reviewCount: reviewCount,
    soldCount: soldCount,
    availableSizes: availableSizes,
    availableColors: availableColors,
    badge: badge,
    isFavorite: isFavorite,
    stock: stock,
  );

  String get formattedPrice => _formatRupiah(price);

  String? get formattedOriginalPrice =>
      originalPrice != null ? _formatRupiah(originalPrice!) : null;

  int? get discountPercentage {
    if (originalPrice != null && originalPrice! > price) {
      return (((originalPrice! - price) / originalPrice!) * 100).round();
    }
    return null;
  }

  static String _formatRupiah(int value) {
    final valStr = value.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valStr.replaceAllMapped(reg, (m) => '${m[1]}.')}';
  }
}
