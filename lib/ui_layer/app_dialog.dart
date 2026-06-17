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
  AppDialog._();

  static void showSuccess(BuildContext context, {required String message}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AppDialogWidget(type: _DialogType.success, message: message),
    );
  }

  static void showError(BuildContext context, {required String message}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AppDialogWidget(type: _DialogType.error, message: message),
    );
  }

  static Future<bool> showConfirm(
      BuildContext context, {
        required String message,
        String confirmLabel = "Yes",
        String cancelLabel = "Cancel",
      }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AppConfirmWidget(
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result ?? false;
  }
}

// ── Internal ────────────────────────────────────────────────────────────────

enum _DialogType { success, error }

class _AppDialogWidget extends StatelessWidget {
  final _DialogType type;
  final String message;
  const _AppDialogWidget({required this.type, required this.message});

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

class _AppConfirmWidget extends StatelessWidget {
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  const _AppConfirmWidget({
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

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
            const SizedBox(height: 8),
            Image.asset(
              'assets/images/night_cloud_fluffy.png',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // ADD THIS
              children: [
                SizedBox(
                  width: 130,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: ColorTheme.deepNavyBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cancelLabel,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ColorTheme.deepNavyBlue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: ColorTheme.orange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ColorTheme.cream,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}