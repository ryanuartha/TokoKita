import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokokita/data/product_data.dart';
import 'package:tokokita/screens/product_detail_screen.dart';
import 'package:tokokita/widgets/product_card_grid.dart';

void main() {
  testWidgets('home product card displays its current stock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 190,
            height: 260,
            child: ProductCardGrid(
              product: products.first.copyWithStock(4),
              onTap: () {},
              isFavorite: false,
              onFavoriteToggle: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sisa 4 unit'), findsOneWidget);
  });

  testWidgets('home card orders details and omits the shipping label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 190,
            height: 340,
            child: ProductCardGrid(
              product: products.first.copyWithStock(18),
              onTap: () {},
              isFavorite: false,
              onFavoriteToggle: () {},
            ),
          ),
        ),
      ),
    );

    final originalPrice = find.text(products.first.formattedOriginalPrice!);
    expect(find.text(products.first.formattedPrice), findsOneWidget);
    final originalPriceRect = tester.getRect(originalPrice);
    final strikeLineRect = tester.getRect(
      find.byKey(const ValueKey<String>('original-price-strikethrough')),
    );
    expect(strikeLineRect.center.dy, closeTo(originalPriceRect.center.dy, 0.5));
    expect(strikeLineRect.width, closeTo(originalPriceRect.width, 0.5));
    expect(find.text('Bebas Ongkir'), findsNothing);
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('Belum terjual'), findsOneWidget);

    final categoryTop = tester
        .getTopLeft(find.text(products.first.category.toUpperCase()))
        .dy;
    final productNameTop = tester.getTopLeft(find.text(products.first.name)).dy;
    final priceTop = tester
        .getTopLeft(find.text(products.first.formattedPrice))
        .dy;
    final stockTop = tester.getTopLeft(find.text('18 unit tersedia')).dy;
    final ratingTop = tester.getTopLeft(find.byIcon(Icons.star_rounded)).dy;

    expect(categoryTop, lessThan(productNameTop));
    expect(productNameTop, lessThan(priceTop));
    expect(priceTop, lessThan(stockTop));
    expect(stockTop, lessThan(ratingTop));
  });

  testWidgets('product details display current stock', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailScreen(
          product: products.first.copyWithStock(12),
          isFavorite: false,
          onFavoriteToggle: () {},
          onAddToCart: (quantity, size, color) {},
          userName: 'Pengguna',
          userEmail: 'pengguna@example.com',
        ),
      ),
    );

    final productName = find.text(products.first.name);
    final stockLabel = find.text('Tersedia 12 unit');
    expect(productName, findsOneWidget);
    expect(stockLabel, findsOneWidget);
    expect(
      tester.getTopLeft(stockLabel).dx,
      greaterThan(tester.getTopLeft(productName).dx),
    );
    expect(
      tester.getCenter(stockLabel).dy,
      lessThan(tester.getBottomLeft(productName).dy),
    );
    expect(find.text(products.first.category.toUpperCase()), findsOneWidget);
    expect(find.text(products.first.formattedOriginalPrice!), findsOneWidget);
    expect(
      find.text('Hemat ${products.first.discountPercentage}%'),
      findsOneWidget,
    );
    expect(find.text('Pilih Ukuran'), findsOneWidget);
    expect(find.text('Pilih Warna'), findsOneWidget);
    expect(find.text('+ Ikuti'), findsOneWidget);
    expect(find.text('TokoKita Official'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.text('Yogyakarta'), findsOneWidget);
    expect(find.text('Kebijakan pengembalian'), findsOneWidget);
    expect(
      find.text(
        'Ajukan melalui Pusat Bantuan jika barang diterima rusak atau tidak '
        'sesuai. Pengajuan akan ditinjau berdasarkan kondisi barang dan '
        'ketentuan toko.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 / 1'), findsNothing);

    await tester.tap(find.text('+ Ikuti'));
    await tester.pump();
    expect(find.text('Mengikuti'), findsOneWidget);
  });

  testWidgets('selected variants are passed to add-to-cart', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? selectedSize;
    String? selectedColor;
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailScreen(
          product: products.first.copyWithStock(12),
          isFavorite: false,
          onFavoriteToggle: () {},
          onAddToCart: (quantity, size, color) {
            selectedSize = size;
            selectedColor = color;
          },
          userName: 'Pengguna',
          userEmail: 'pengguna@example.com',
        ),
      ),
    );

    await tester.ensureVisible(find.text('L'));
    await tester.tap(find.text('L'));
    await tester.ensureVisible(find.text('Navy'));
    await tester.tap(find.text('Navy'));
    await tester.tap(find.text('+ Keranjang'));

    expect(selectedSize, 'L');
    expect(selectedColor, 'Navy');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('out-of-stock products show an unavailable label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 190,
            height: 260,
            child: ProductCardGrid(
              product: products.first.copyWithStock(0),
              onTap: () {},
              isFavorite: false,
              onFavoriteToggle: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Stok habis'), findsOneWidget);
  });
}
