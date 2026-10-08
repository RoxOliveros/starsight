import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../business_layer/auth_service.dart';
import '../business_layer/database_service.dart';

abstract class _FpPalette {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color orange = Color(0xFFEC8A20);
  static const Color teal = Color(0xFF54BDB8);
  static const Color navy = Color(0xFF5F7199);
  static const Color brown = Color(0xFF5E463E);
  static const Color red = Color(0xFFD9534F);
}

const String _fredoka = 'Fredoka';

enum _Step { verify, newPin }

/// Forgot PIN flow:
///   1. Parent proves it's them by re-entering their account password
///      (or by signing in with Google again).
///   2. Parent chooses a new 4-digit PIN.
/// Pops with `true` once the new PIN has been saved.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _newPinCtrl = TextEditingController();
  final TextEditingController _confirmPinCtrl = TextEditingController();

  _Step _step = _Step.verify;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _showPasswordForm = false; // only used when the account has both
  String? _error;

  late final bool _hasGoogle;
  late final bool _hasPassword;

  @override
  void initState() {
    super.initState();
    OrientationService.setPortrait();
    final providers = _auth.signInProviders;
    debugPrint('Forgot PIN - sign-in providers: $providers');
    _hasGoogle = providers.contains('google.com');
    // If we can't tell, default to the password option.
    _hasPassword = providers.contains('password') || !_hasGoogle;
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
    OrientationService.setLandscape();
  }

  /// Wording that matches how this account signs in.
  String get _verifySubtitle {
    if (_hasGoogle && !_hasPassword) {
      return 'You signed up with Google, so please confirm it is you by '
          'signing in with Google again.';
    }
    if (_hasGoogle) {
      return 'This account uses Google sign-in. Please confirm it is you '
          'with Google.';
    }
    return 'Please enter your account password to confirm it is you.';
  }

  // ── Step 1: verify ───────────────────────────────────────────────────────

  Future<void> _verifyWithPassword() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    await _runVerify(() => _auth.reauthenticateWithPassword(password));
  }

  Future<void> _verifyWithGoogle() =>
      _runVerify(_auth.reauthenticateWithGoogle);

  Future<void> _runVerify(Future<String?> Function() verify) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await verify(); // null = success

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) {
        _passwordCtrl.clear();
        _step = _Step.newPin;
      }
    });
  }

  // ── Step 2: new PIN ──────────────────────────────────────────────────────

  Future<void> _saveNewPin() async {
    if (_busy) return;

    final pin = _newPinCtrl.text;
    final confirm = _confirmPinCtrl.text;

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'Your PIN must be exactly 4 digits.');
      return;
    }
    // Same rule as PIN setup at sign-up (parents_pin_setup.dart).
    if (pin.split('').toSet().length == 1) {
      setState(
        () => _error =
            'PIN is too weak. Please do not use repeating numbers (e.g., 1111).',
      );
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'The PINs do not match. Please try again.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await DatabaseService().updateParentPin(pin);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error != null) return;

    await _showSuccessCard();
    OrientationService.setLandscape();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _showSuccessCard() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: _FpPalette.cream,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _FpPalette.teal, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconBadge(Icons.check_circle_rounded, _FpPalette.teal),
                const SizedBox(height: 12),
                const Text(
                  'PIN UPDATED!',
                  style: TextStyle(
                    fontFamily: _fredoka,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _FpPalette.teal,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your new PIN is ready. Use it the next time you open '
                  'the Grownup area.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: _FpPalette.brown,
                  ),
                ),
                const SizedBox(height: 18),
                _primaryButton(
                  label: 'BACK TO KEYPAD',
                  color: _FpPalette.teal,
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final verifying = _step == _Step.verify;

    return Scaffold(
      backgroundColor: _FpPalette.cream,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: _iconBadge(
                          verifying
                              ? Icons.lock_reset_rounded
                              : Icons.pin_rounded,
                          _FpPalette.orange,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        verifying ? "VERIFY IT'S YOU" : 'SET A NEW PIN',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: _fredoka,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _FpPalette.orange,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        verifying
                            ? _verifySubtitle
                            : 'Choose a new 4-digit PIN for the Grownup area.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _FpPalette.brown,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (verifying)
                        ..._buildVerifyStep()
                      else
                        ..._buildNewPinStep(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _FpPalette.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: _FpPalette.brown,
                  size: 28,
                ),
                onPressed: _busy
                    ? null
                    : () {
                        OrientationService.setLandscape();
                        Navigator.pop(context);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVerifyStep() {
    // Google comes first whenever the account uses it. The password form
    // shows straight away only for accounts without Google, or when a
    // parent who has both taps "Use my account password instead".
    final googleFirst = _hasGoogle;
    final showPassword = !googleFirst || _showPasswordForm;

    return [
      if (googleFirst) ...[
        _buildGoogleReminder(),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _verifyWithGoogle,
            style: ElevatedButton.styleFrom(
              backgroundColor: _FpPalette.orange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _FpPalette.orange.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.account_circle_rounded),
            label: const Text(
              'CONTINUE WITH GOOGLE',
              style: TextStyle(
                fontFamily: _fredoka,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
      if (googleFirst && _hasPassword && !_showPasswordForm)
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _showPasswordForm = true;
                  _error = null;
                }),
          child: const Text(
            'Use my account password instead',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              color: _FpPalette.navy,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      if (googleFirst && showPassword) const SizedBox(height: 14),
      if (showPassword) ...[
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verifyWithPassword(),
          decoration: _fieldDecoration(
            'Account password',
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: _FpPalette.navy,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton(
          label: 'CONTINUE',
          color: _FpPalette.orange,
          busy: _busy,
          onPressed: _verifyWithPassword,
        ),
      ],
    ];
  }

  /// Friendly reminder box shown to parents whose account uses Google.
  Widget _buildGoogleReminder() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _FpPalette.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _FpPalette.teal, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: _FpPalette.teal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _hasPassword
                  ? 'This account uses Google sign-in. Tap the button below '
                        'to confirm it is you.'
                  : 'You signed up with Google, so there is no password for '
                        'this account. Just tap the button below.',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: _FpPalette.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNewPinStep() {
    return [
      _pinField(_newPinCtrl, 'New PIN', TextInputAction.next),
      const SizedBox(height: 12),
      _pinField(
        _confirmPinCtrl,
        'Confirm new PIN',
        TextInputAction.done,
        onSubmitted: (_) => _saveNewPin(),
      ),
      const SizedBox(height: 16),
      _primaryButton(
        label: 'SAVE NEW PIN',
        color: _FpPalette.orange,
        busy: _busy,
        onPressed: _saveNewPin,
      ),
    ];
  }

  Widget _pinField(
    TextEditingController controller,
    String label,
    TextInputAction action, {
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      obscureText: true,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      textInputAction: action,
      onSubmitted: onSubmitted,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      style: const TextStyle(
        fontFamily: _fredoka,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 8,
        color: _FpPalette.brown,
      ),
      decoration: _fieldDecoration(label),
    );
  }

  InputDecoration _fieldDecoration(String label, {Widget? suffix}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: c, width: 1.6),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w700,
        color: _FpPalette.brown,
      ),
      floatingLabelAlignment: FloatingLabelAlignment.center,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.6),
      suffixIcon: suffix,
      enabledBorder: border(_FpPalette.orange.withValues(alpha: 0.6)),
      focusedBorder: border(_FpPalette.orange),
      disabledBorder: border(_FpPalette.brown.withValues(alpha: 0.2)),
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      child: Icon(icon, size: 34, color: color),
    );
  }

  Widget _primaryButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool busy = false,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        // While busy: stays orange but ignores taps.
        onPressed: busy ? () {} : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: _fredoka,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
