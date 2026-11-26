import 'package:material_ui/material_ui.dart';

import '../models/product.dart';
import '../theme/app_colors.dart';
import 'bounce_button.dart';
import 'strikethrough_price.dart';

class ProductCardGrid extends StatefulWidget {
  const ProductCardGrid({
    super.key,
    required this.product,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.onAddToCart,
  });

  final Product product;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onAddToCart;

  @override
  State<ProductCardGrid> createState() => _ProductCardGridState();
}

class _ProductCardGridState extends State<ProductCardGrid> {
  bool _isCartAdded = false;

  void _triggerAddToCartAnimation() {
    if (widget.onAddToCart != null) {
      widget.onAddToCart!();
      setState(() => _isCartAdded = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _isCartAdded = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.product.stock;
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
    final stockLabel = stock == null
        ? 'Memuat stok'
        : stock == 0
        ? 'Stok habis'
        : stock <= 5
        ? 'Sisa $stock unit'
        : '$stock unit tersedia';

    return BounceButton(
      onPressed: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // MAIN CONTENT COLUMN
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IMAGE CONTAINER WITH 4:3 RECTANGULAR ASPECT RATIO
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          widget.product.imageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: AppColors.background,
                                child: const Icon(
                                  Icons.image_not_supported_rounded,
                                  color: AppColors.textSecondary,
                                  size: 32,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                // PRODUCT DETAILS SECTION WITH SCROLLABLE WRAPPER FOR ROTATION / LANDSCAPE SAFETY
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 6, 9, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.category.toUpperCase(),
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.8,
                              ),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 5,
                            runSpacing: 0,
                            children: [
                              Text(
                                widget.product.formattedPrice,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (widget.product.originalPrice != null &&
                                  widget.product.originalPrice! >
                                      widget.product.price)
                                StrikethroughPrice(
                                  text: widget.product.formattedOriginalPrice!,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: stockBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              stockLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: stockColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFB400),
                                size: 12,
                              ),
                              SizedBox(width: 2),
                              Text(
                                '0.0',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 5),
                              Text(
                                '|',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                ),
                              ),
                              SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Belum terjual',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // TOP-RIGHT FAVORITE (LOVE) BUTTON
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: Colors.black26,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onFavoriteToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        widget.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(widget.isFavorite),
                        color: widget.isFavorite
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // BOTTOM-RIGHT CART ICON BUTTON (CLEAN ICON, NO BACKGROUND BOX)
            if (widget.onAddToCart != null)
              Positioned(
                bottom: 6,
                right: 6,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _triggerAddToCartAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        _isCartAdded
                            ? Icons.check_rounded
                            : Icons.add_shopping_cart_rounded,
                        key: ValueKey(_isCartAdded),
                        color: _isCartAdded
                            ? AppColors.accentTeal
                            : AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
