import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../business_layer/audio_helper.dart';
import '../business_layer/auth_service.dart';
import '../business_layer/database_service.dart';
import '../business_layer/orientation_service.dart';
import 'app_dialog.dart' show AppDialog;
import 'signin_account.dart' show SignInAccount;

abstract class _AccPalette {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color teal = Color(0xFF54BDB8);
  static const Color brown = Color(0xFF6F6764);
  static const Color mutedGrey = Color(0xFFB9B2A9);
  static const Color titleSky = Color(0xFF6FD3E3);
  static const Color titleGold = Color(0xFFFACC58);
  static const Color titleOrange = Color(0xFFEC8A20);
}

abstract class _AccFonts {
  static const String fredoka = 'Fredoka';
}

const int _pinLength = 4; // change if your PIN is a different length

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  // ── Actions ──────────────────────────────────────────────────────────────

  // Opens the sign-in screen on top of this one. The parent stays signed in
  // until they successfully sign in to a DIFFERENT account, and the back arrow
  // there brings them back here if they change their mind.
  void _switchAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SignInAccount(isSwitchingAccount: true),
      ),
    );
  }

  // Used after the account is deleted: clears the whole stack.
  Future<void> _goToSignIn(BuildContext context) async {
    await OrientationService.setPortrait();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInAccount()),
      (route) => false,
    );

    // Some of the screens being closed switch the app back to landscape at
    // moments we can't predict, so keep re-applying portrait for a short
    // window. This keeps any landscape flash down to a split second.
    var ticks = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      OrientationService.setPortrait();
      if (++ticks >= 25) timer.cancel();
    });
  }

  Future<void> _changePin(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePinDialog(),
    );
    if (changed == true && context.mounted) {
      AppDialog.showSuccess(context, message: 'Your PIN has been updated!');
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final auth = AuthService();
    if (!auth.usesPassword) {
      // Signed in with Google only: there's no password to change.
      AppDialog.showError(
        context,
        message: "You signed in with Google, so there's no password to change.",
      );
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      AppDialog.showError(
        context,
        message: "You're not signed in. Please sign in and try again.",
      );
      return;
    }

    final confirm = await AppDialog.showConfirm(
      context,
      message: "We'll send a password reset link to $email.",
      confirmLabel: 'Send',
    );
    if (!confirm || !context.mounted) return;

    _showLoading(context);
    final error = await auth.sendPasswordResetEmail(email);
    if (!context.mounted) return;
    Navigator.pop(context); // dismiss the loading circle

    if (error == null) {
      AppDialog.showSuccess(
        context,
        message:
            "Check your inbox for a link to reset your password.\n\nBe sure to check your spam folder!",
      );
    } else {
      AppDialog.showError(context, message: error);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(auth: AuthService()),
    );
    if (deleted != true || !context.mounted) return;

    AppDialog.showSuccessAction(
      context,
      title: 'Account deleted',
      message:
          'Your account and all of its data have been permanently deleted.',
      actionLabel: 'OK',
      onAction: () => _goToSignIn(context),
    );
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _AccPalette.cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildRainbowTitle('ACCOUNT')),
                    const SizedBox(height: 28),

                    // ── Email card (orange) ──
                    _buildOutlinedCard(
                      borderColor: _AccPalette.orange,
                      children: [
                        _AccRow(
                          icon: Icons.email_rounded,
                          color: _AccPalette.orange,
                          label: 'Email',
                          value: email,
                          showChevron: false,
                          trailing: _SwitchAccountButton(
                            onTap: () {
                              SfxHelper.instance.play(Sfx.keyTap);
                              _switchAccount(context);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Security card (teal) ──
                    _buildOutlinedCard(
                      borderColor: _AccPalette.teal,
                      children: [
                        _AccRow(
                          icon: Icons.pin_rounded,
                          color: _AccPalette.teal,
                          label: 'Change PIN',
                          onTap: () {
                            SfxHelper.instance.play(Sfx.keyTap);
                            _changePin(context);
                          },
                        ),
                        Divider(
                          height: 1,
                          color: _AccPalette.teal.withValues(alpha: 0.25),
                        ),
                        _AccRow(
                          icon: Icons.lock_rounded,
                          color: _AccPalette.teal,
                          label: 'Change Password',
                          onTap: () {
                            SfxHelper.instance.play(Sfx.keyTap);
                            _changePassword(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Delete account (red pill) ──
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          SfxHelper.instance.play(Sfx.keyTap);
                          _deleteAccount(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.6),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'DELETE ACCOUNT',
                          style: TextStyle(
                            fontFamily: _AccFonts.fredoka,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _AccPalette.deepNavyBlue,
          ),
          onPressed: () {
            SfxHelper.instance.play(Sfx.keyTap);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // Multicolored title (same style as the Grownup's Area)
  Widget _buildRainbowTitle(String text) {
    const palette = [
      _AccPalette.titleSky,
      _AccPalette.titleGold,
      _AccPalette.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = _AccPalette.brown;
      } else {
        color = palette[(letterIndex ~/ 2) % palette.length];
        letterIndex++;
      }
      spans.add(
        TextSpan(
          text: char,
          style: TextStyle(color: color),
        ),
      );
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: _AccFonts.fredoka,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildOutlinedCard({
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.6),
      ),
      child: Column(children: children),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Form dialogs (styled to match AppDialog)
// ════════════════════════════════════════════════════════════════════════════

class _AccDialogShell extends StatelessWidget {
  final String title;
  final Widget content;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final bool loading;
  final Color confirmColor;

  const _AccDialogShell({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.onConfirm,
    this.loading = false,
    this.confirmColor = _AccPalette.orange,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Block back-button dismissal while something is saving/deleting.
    return PopScope(
      canPop: !loading,
      child: Dialog(
        backgroundColor: _AccPalette.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth < 400 ? screenWidth * 0.9 : 360,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _AccFonts.fredoka,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _AccPalette.deepNavyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                content,
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Cancel',
                        background: _AccPalette.deepNavyBlue.withValues(
                          alpha: 0.15,
                        ),
                        textColor: _AccPalette.deepNavyBlue,
                        onTap: loading
                            ? null
                            : () {
                                SfxHelper.instance.play(Sfx.keyTap);
                                Navigator.pop(context, false);
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: confirmLabel,
                        background: confirmColor,
                        textColor: _AccPalette.cream,
                        loading: loading,
                        onTap: loading
                            ? null
                            : () {
                                SfxHelper.instance.play(Sfx.keyTap);
                                onConfirm();
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;
  final VoidCallback? onTap;
  final bool loading;

  const _DialogButton({
    required this.label,
    required this.background,
    required this.textColor,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: textColor,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontFamily: _AccFonts.fredoka,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
      ),
    );
  }
}

Widget _dialogField({
  required TextEditingController controller,
  required String label,
  bool isPin = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      obscureText: true,
      keyboardType: isPin ? TextInputType.number : TextInputType.text,
      inputFormatters: isPin
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_pinLength),
            ]
          : null,
      onTap: () => SfxHelper.instance.play(Sfx.keyTap),
      style: const TextStyle(
        fontFamily: _AccFonts.fredoka,
        fontSize: 15,
        color: _AccPalette.deepNavyBlue,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: _AccFonts.fredoka,
          fontSize: 14,
          color: _AccPalette.deepNavyBlue,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: _AccPalette.deepNavyBlue,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: _AccPalette.teal, width: 2),
        ),
      ),
    ),
  );
}

// ── Change PIN ──────────────────────────────────────────────────────────────

class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog();

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final _db = DatabaseService();
  bool _loading = false;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_new.text.length != _pinLength) {
      AppDialog.showError(
        context,
        message: 'Your new PIN must be $_pinLength digits.',
      );
      return;
    }
    // Same rule as PIN setup: no repeating digits like 1111.
    if (_new.text.split('').toSet().length == 1) {
      AppDialog.showError(
        context,
        message:
            "PIN is too weak. Please do not use repeating numbers (e.g., 1111).",
      );
      return;
    }
    if (_new.text != _confirm.text) {
      AppDialog.showError(context, message: "The new PINs don't match.");
      return;
    }

    setState(() => _loading = true);

    // The new PIN can't be the one already in use.
    final currentPin = await _db.getParentPin();
    if (!mounted) return;
    if (currentPin == _new.text) {
      setState(() => _loading = false);
      AppDialog.showError(
        context,
        message: 'Your new PIN must be different from your current PIN.',
      );
      return;
    }

    final error = await _db.updateParentPin(_new.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _loading = false);
      AppDialog.showError(context, message: error);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _AccDialogShell(
      title: 'Change PIN',
      confirmLabel: 'Save',
      loading: _loading,
      onConfirm: _submit,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dialogField(controller: _new, label: 'New PIN:', isPin: true),
          _dialogField(
            controller: _confirm,
            label: 'Confirm new PIN:',
            isPin: true,
          ),
        ],
      ),
    );
  }
}

// ── Delete Account ──────────────────────────────────────────────────────────

class _DeleteAccountDialog extends StatefulWidget {
  final AuthService auth;
  const _DeleteAccountDialog({required this.auth});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _pin = TextEditingController();
  final _password = TextEditingController();
  final _db = DatabaseService();
  bool _loading = false;

  // Google-only accounts have no password; they re-verify with Google instead.
  late final bool _usesPassword = widget.auth.usesPassword;

  @override
  void dispose() {
    _pin.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fail(String message) {
    setState(() => _loading = false);
    AppDialog.showError(context, message: message);
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_pin.text.length != _pinLength) {
      AppDialog.showError(context, message: 'Please enter your PIN.');
      return;
    }
    if (_usesPassword && _password.text.isEmpty) {
      AppDialog.showError(context, message: 'Please enter your password.');
      return;
    }

    setState(() => _loading = true);

    // 1. PIN
    final savedPin = await _db.getParentPin();
    if (!mounted) return;
    if (savedPin == null || savedPin != _pin.text) {
      _fail("That PIN isn't right.");
      return;
    }

    // 2. Password (or Google) re-verification
    final verifyError = _usesPassword
        ? await widget.auth.reauthenticateWithPassword(_password.text)
        : await widget.auth.reauthenticateWithGoogle();
    if (!mounted) return;
    if (verifyError != null) {
      _fail(verifyError);
      return;
    }

    // 3. Data first (needs the user signed in), then the account itself.
    final dataError = await _db.deleteAllAccountData();
    if (!mounted) return;
    if (dataError != null) {
      _fail(dataError);
      return;
    }

    final authError = await widget.auth.deleteAccount();
    if (!mounted) return;
    if (authError != null) {
      _fail(authError);
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _AccDialogShell(
      title: 'Delete Account',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
      loading: _loading,
      onConfirm: _submit,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          const Text(
            "This will permanently delete your account and all of your children's progress. This can't be undone.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _AccFonts.fredoka,
              fontSize: 14,
              color: _AccPalette.brown,
            ),
          ),
          _dialogField(controller: _pin, label: 'PIN:', isPin: true),
          if (_usesPassword)
            _dialogField(controller: _password, label: 'Password:'),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Existing widgets (unchanged)
// ════════════════════════════════════════════════════════════════════════════

// Small round "switch account" button shown on the email row
class _SwitchAccountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SwitchAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _AccPalette.orange.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.swap_horiz_rounded,
          size: 22,
          color: _AccPalette.orange,
        ),
      ),
    );
  }
}

class _AccRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final bool showChevron;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _AccRow({
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.showChevron = true,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: _AccFonts.fredoka,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _AccPalette.deepNavyBlue,
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _AccFonts.fredoka,
                          fontSize: 13,
                          color: _AccPalette.brown,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: _AccPalette.deepNavyBlue.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
