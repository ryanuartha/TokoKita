import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_colors.dart';
import 'bounce_button.dart';

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
    final hasDiscount =
        widget.product.originalPrice != null &&
        widget.product.originalPrice! > widget.product.price;

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
                    child: Image.asset(
                      widget.product.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.background,
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          color: AppColors.textSecondary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

                // PRODUCT DETAILS SECTION WITH SCROLLABLE WRAPPER FOR ROTATION / LANDSCAPE SAFETY
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 6, 38, 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.category.toUpperCase(),
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.8),
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
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
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
                              if (hasDiscount &&
                                  widget.product.formattedOriginalPrice != null) ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    widget.product.formattedOriginalPrice!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 8.5,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentTealLight,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: AppColors.accentTeal.withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_shipping_rounded,
                                  color: AppColors.accentTeal,
                                  size: 9,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Bebas Ongkir',
                                  style: TextStyle(
                                    color: AppColors.accentTeal,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppColors.starYellow,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.product.rating}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '| ${widget.product.soldCount}+ terjual',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 8.5,
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

            // TOP-LEFT BADGES (Official Store & Discount)
            Positioned(
              top: 6,
              left: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.product.badge != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD0011B), Color(0xFFE53935)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 9,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.product.badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasDiscount && widget.product.discountPercentage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '-${widget.product.discountPercentage}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
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
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
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
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
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
