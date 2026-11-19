import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_colors.dart';
import 'bounce_button.dart';

class ProductBox extends StatefulWidget {
  const ProductBox({
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
  State<ProductBox> createState() => _ProductBoxState();
}

class _ProductBoxState extends State<ProductBox> {
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
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 95,
                      height: 95,
                      child: Image.asset(
                        widget.product.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.background,
                          child: const Icon(
                            Icons.image_not_supported_rounded,
                            color: AppColors.textSecondary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.product.badge != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryMall,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          widget.product.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.product.category.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onFavoriteToggle,
                          child: Icon(
                            widget.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: widget.isFavorite
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // PRODUCT TITLE
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // PRICE & DISCOUNT TAG
                    Row(
                      children: [
                        Text(
                          widget.product.formattedPrice,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: AppColors.primary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (hasDiscount &&
                            widget.product.discountPercentage != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            widget.product.formattedOriginalPrice!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '-${widget.product.discountPercentage}%',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // RATING, SOLD COUNT & ADD TO CART BUTTON
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.starYellow,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${widget.product.rating}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• ${widget.product.soldCount}+ terjual',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        if (widget.onAddToCart != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _triggerAddToCartAnimation,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _isCartAdded
                                    ? AppColors.accentTeal
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isCartAdded
                                            ? AppColors.accentTeal
                                            : AppColors.primary)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isCartAdded
                                        ? Icons.check_rounded
                                        : Icons.add_shopping_cart_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isCartAdded ? 'Beli' : '+ Keranjang',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
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
  }
}
