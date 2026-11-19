import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SliderIconIndicator extends StatelessWidget {
  const SliderIconIndicator({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    this.isInsideBanner = false,
    this.activeIcon = Icons.local_fire_department_rounded,
    this.onTap,
  });

  final int itemCount;
  final int currentIndex;
  final bool isInsideBanner;
  final IconData activeIcon;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(itemCount, (index) {
        final distance = (currentIndex - index).abs();
        final isActive = index == currentIndex;

        double size;
        Color bgColor;
        Color iconColor;

        if (isActive) {
          size = 18.0;
          bgColor = isInsideBanner ? Colors.white : AppColors.primary;
          iconColor = isInsideBanner ? AppColors.primary : Colors.white;
        } else {
          size = 6.0;
          if (distance == 1) {
            bgColor = isInsideBanner
                ? Colors.white.withValues(alpha: 0.5)
                : const Color(0xFFCCCCCC);
          } else {
            bgColor = isInsideBanner
                ? Colors.white.withValues(alpha: 0.25)
                : const Color(0xFFE0E0E0);
          }
          iconColor = Colors.transparent;
        }

        return GestureDetector(
          onTap: onTap != null ? () => onTap!(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: isActive
                ? Center(child: Icon(activeIcon, size: 12.0, color: iconColor))
                : null,
          ),
        );
      }),
    );
  }
}
