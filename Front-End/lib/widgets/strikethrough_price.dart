import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

class StrikethroughPrice extends StatelessWidget {
  const StrikethroughPrice({
    super.key,
    required this.text,
    required this.style,
    this.lineColor = AppColors.textMuted,
  });

  final String text;
  final TextStyle style;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, style: style),
        Positioned.fill(
          child: Center(
            child: Container(
              key: const ValueKey<String>('original-price-strikethrough'),
              width: double.infinity,
              height: 1,
              color: lineColor,
            ),
          ),
        ),
      ],
    );
  }
}
