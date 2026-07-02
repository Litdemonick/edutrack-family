import 'package:flutter/material.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
// CUSTOM BUTTON — EduTrack Family
// Botones reutilizables con estado de carga y variantes.
// ═══════════════════════════════════════════════════════════════

enum ButtonVariant { primary, secondary, danger, ghost }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final IconData? icon;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.width,
    this.height = 52,
  });

  const CustomButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 52,
  }) : variant = ButtonVariant.secondary;

  const CustomButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 52,
  }) : variant = ButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;
    Color? borderColor;

    switch (variant) {
      case ButtonVariant.primary:
        bgColor = AppColors.navyBlue;
        fgColor = Colors.white;
        borderColor = null;
        break;
      case ButtonVariant.secondary:
        bgColor = Colors.transparent;
        fgColor = isDark ? AppColors.skyBlue : AppColors.navyBlue;
        borderColor = isDark ? AppColors.skyBlue : AppColors.navyBlue;
        break;
      case ButtonVariant.danger:
        bgColor = AppColors.statusRed;
        fgColor = Colors.white;
        borderColor = null;
        break;
      case ButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = isDark ? AppColors.skyBlue : AppColors.accentBlue;
        borderColor = null;
        break;
    }

    final content =
        isLoading
            ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: fgColor,
                strokeWidth: 2.5,
              ),
            )
            : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: fgColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            );

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child:
          borderColor != null
              ? OutlinedButton(
                onPressed: isLoading ? null : onPressed,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: content,
              )
              : ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgColor,
                  foregroundColor: fgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: content,
              ),
    );
  }
}
