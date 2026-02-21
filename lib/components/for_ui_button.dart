import 'package:flutter/material.dart';
import '../theme/for_ui.dart';

class ForUIButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isFullWidth;
  final IconData? icon;
  final bool isLoading;
  final bool isSmall;

  const ForUIButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isFullWidth = false,
    this.icon,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: isSmall ? 36 : ForUI.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? theme.colorScheme.primary : Colors.transparent,
          foregroundColor:
              isPrimary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
          elevation: isPrimary ? ForUI.buttonElevation : 0,
          padding:
              isSmall
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  : ForUI.buttonPadding,
          side: isPrimary ? null : BorderSide(color: theme.colorScheme.primary),
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmall ? 14 : 16,
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  width: isSmall ? 16 : 20,
                  height: isSmall ? 16 : 20,
                  child: CircularProgressIndicator(
                    strokeWidth: isSmall ? 2 : 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPrimary
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize:
                      isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: isSmall ? 16 : 18),
                      SizedBox(width: isSmall ? 4 : 8),
                    ],
                    Flexible(
                      child: Text(text, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
      ),
    );
  }
}
