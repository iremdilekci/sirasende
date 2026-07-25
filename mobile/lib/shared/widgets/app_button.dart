import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;
  final bool isOutlined;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: isOutlined
          ? (onPressed == null ? AppColors.disabled : AppColors.primary)
          : Colors.white,
    );

    final Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutlined ? AppColors.primary : Colors.white,
              ),
            ),
          )
        : (icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isOutlined ? AppColors.primary : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(label, style: textStyle),
                  ],
                )
              : Text(label, style: textStyle));

    final buttonStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(88, 50)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isOutlined ? Colors.transparent : AppColors.disabled;
        }
        return isOutlined ? Colors.transparent : AppColors.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textSecondary;
        }
        return isOutlined ? AppColors.primary : Colors.white;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (isOutlined) {
          final color = states.contains(WidgetState.disabled)
              ? AppColors.disabled
              : AppColors.primary;
          return BorderSide(color: color, width: 1.5);
        }
        return null;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        return isOutlined
            ? AppColors.primary.withOpacity(0.08)
            : Colors.white.withOpacity(0.12);
      }),
    );

    Widget button;
    if (isOutlined) {
      button = OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle,
        child: content,
      );
    } else {
      button = FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle,
        child: content,
      );
    }

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
