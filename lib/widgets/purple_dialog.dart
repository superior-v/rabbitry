import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable Bright Purple Dialog matching the app's lilac pastel design system.
/// Features a bright purple header with white title & close button,
/// lilac border, and clean body content.
class BrightPurpleDialog extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final String? content;
  final Widget? contentWidget;
  final List<Widget>? actions;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color headerColor;
  final Color borderColor;
  final Color? confirmColor;
  final bool isDestructive;
  final bool showCloseButton;
  final TextAlign textAlign;
  final EdgeInsets? contentPadding;

  const BrightPurpleDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.content,
    this.contentWidget,
    this.actions,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.headerColor = const Color(0xFFC3B1E1), // Bright lilac / purple
    this.borderColor = const Color(0xFFC3B1E1),
    this.confirmColor,
    this.isDestructive = false,
    this.showCloseButton = true,
    this.textAlign = TextAlign.center,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: headerColor,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: titleWidget ??
                        Text(
                          title ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                  ),
                  if (showCloseButton)
                    GestureDetector(
                      onTap: () {
                        if (onCancel != null) {
                          onCancel!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: contentPadding ?? const EdgeInsets.fromLTRB(22, 22, 22, 16),
              child: contentWidget ??
                  (content != null
                      ? Text(
                          content!,
                          textAlign: textAlign,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Color(0xFF3A3A3C),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : const SizedBox.shrink()),
            ),

            // Actions Area
            if (actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              )
            else if (confirmText != null || cancelText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cancelText != null) ...[
                      TextButton(
                        onPressed: () {
                          if (onCancel != null) {
                            onCancel!();
                          } else {
                            Navigator.of(context).pop(false);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF787774),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: Text(
                          cancelText!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (confirmText != null)
                      TextButton(
                        onPressed: () {
                          if (onConfirm != null) {
                            onConfirm!();
                          } else {
                            Navigator.of(context).pop(true);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: isDestructive
                              ? const Color(0xFFD44C47)
                              : (confirmColor ?? kLilacDeep),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: Text(
                          confirmText!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDestructive
                                ? const Color(0xFFD44C47)
                                : (confirmColor ?? kLilacDeep),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show a styled bright purple dialog
Future<T?> showBrightPurpleDialog<T>({
  required BuildContext context,
  String? title,
  Widget? titleWidget,
  String? content,
  Widget? contentWidget,
  List<Widget>? actions,
  String? confirmText,
  String? cancelText,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  Color headerColor = const Color(0xFFC3B1E1),
  Color borderColor = const Color(0xFFC3B1E1),
  Color? confirmColor,
  bool isDestructive = false,
  bool showCloseButton = true,
  TextAlign textAlign = TextAlign.center,
  EdgeInsets? contentPadding,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => BrightPurpleDialog(
      title: title,
      titleWidget: titleWidget,
      content: content,
      contentWidget: contentWidget,
      actions: actions,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: onConfirm,
      onCancel: onCancel,
      headerColor: headerColor,
      borderColor: borderColor,
      confirmColor: confirmColor,
      isDestructive: isDestructive,
      showCloseButton: showCloseButton,
      textAlign: textAlign,
      contentPadding: contentPadding,
    ),
  );
}
