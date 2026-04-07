import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../constants/app_colors.dart';

class ToastUtils {
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context,
      message,
      icon: PhosphorIconsFill.checkCircle,
      backgroundColor: const Color(0xFF7B6BA0),
    );
  }

  static void showError(BuildContext context, String message) {
    _showToast(
      context,
      message,
      icon: PhosphorIconsFill.warningCircle,
      backgroundColor: const Color(0xFFD44C47),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(
      context,
      message,
      icon: PhosphorIconsFill.info,
      backgroundColor: const Color(0xFF2C2C2E),
    );
  }

  static void _showToast(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
