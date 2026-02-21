import 'package:flutter/material.dart';
import '../theme/for_ui.dart';

class ForUICard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;

  const ForUICard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: elevation ?? theme.cardTheme.elevation ?? ForUI.cardElevation,
      color: backgroundColor ?? theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(ForUI.cardRadius),
        side:
            theme.cardTheme.shape is RoundedRectangleBorder
                ? (theme.cardTheme.shape as RoundedRectangleBorder).side
                : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(ForUI.cardRadius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
