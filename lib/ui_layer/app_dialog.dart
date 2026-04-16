import 'package:flutter/material.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color brown = Color(0xFF6F6764);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class AppDialog {
  AppDialog._(); // prevent instantiation

  static void showSuccess(BuildContext context, {required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AppDialogWidget(type: _DialogType.success, message: message),
    );
  }

  static void showError(BuildContext context, {required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AppDialogWidget(type: _DialogType.error, message: message),
    );
  }
}

// ── Internal ────────────────────────────────────────────────────────────────

enum _DialogType { success, error }

class _AppDialogWidget extends StatelessWidget {
  final _DialogType type;
  final String message;
  const _AppDialogWidget({super.key, required this.type, required this.message});

  bool get _isSuccess => type == _DialogType.success;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColorTheme.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: ColorTheme.brown, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Image.asset(
              _isSuccess
                  ? 'assets/images/jar_on_grass.png'
                  : 'assets/images/night_cloud_fluffy.png',
              height: 130,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ColorTheme.brown,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}