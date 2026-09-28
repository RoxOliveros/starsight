import 'package:flutter/material.dart';

import '../business_layer/database_service.dart';
import '../business_layer/screen_time_service.dart';

const String _font = 'Fredoka';
const Color _cream = Color(0xFFFAF7EB);
const Color _navy = Color(0xFF5F7199);
const Color _orange = Color(0xFFEC8A20);
const Color _brown = Color(0xFF6F6764);

/// Wrap the whole app with this (see MaterialApp.builder) so the lock screen
/// appears on top of every screen, including the games, the moment the
/// child's daily limit is reached.
///
///   MaterialApp(
///     builder: (context, child) => ScreenTimeGate(child: child),
///     ...
///   )
class ScreenTimeGate extends StatelessWidget {
  final Widget? child;

  const ScreenTimeGate({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ScreenTimeService.instance.isLocked,
      child: child,
      builder: (context, locked, app) {
        return Stack(
          children: [
            if (app != null) Positioned.fill(child: app),
            if (locked) const Positioned.fill(child: _LockOverlay()),
          ],
        );
      },
    );
  }
}

/// MaterialApp.builder sits *above* the Navigator, so there's no Overlay
/// ancestor for the TextField's selection handles. This gives it its own.
class _LockOverlay extends StatelessWidget {
  const _LockOverlay();

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [OverlayEntry(builder: (_) => const _LockContent())],
    );
  }
}

class _LockContent extends StatefulWidget {
  const _LockContent();

  @override
  State<_LockContent> createState() => _LockContentState();
}

class _LockContentState extends State<_LockContent> {
  final TextEditingController _pinController = TextEditingController();
  bool _showPin = false;
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    final pin = await DatabaseService().getParentPin();
    if (!mounted) return;

    if (pin != null && pin == _pinController.text.trim()) {
      // Lifts the lock for a few minutes so the parent can open the
      // Parent's Area and raise the limit. The overlay removes itself.
      ScreenTimeService.instance.grantParentGrace();
      return;
    }

    setState(() {
      _checking = false;
      _error = "That PIN isn't right. Please try again.";
    });
  }

  @override
  Widget build(BuildContext context) {
    // Material + full-screen fill also swallows all touches, so nothing
    // underneath can be played.
    return Material(
      color: _cream,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 64,
                  color: _orange,
                ),
                const SizedBox(height: 12),
                const Text(
                  "TIME'S UP FOR TODAY!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You've reached your screen time limit.\n"
                  "Come back tomorrow for more fun!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 16,
                    color: _brown,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_showPin)
                  TextButton(
                    onPressed: () => setState(() => _showPin = true),
                    child: const Text(
                      "I'm a parent",
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: 260,
                    child: Column(
                      children: [
                        TextField(
                          controller: _pinController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onSubmitted: (_) => _submitPin(),
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 20,
                            letterSpacing: 6,
                            color: _navy,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Parent PIN',
                            errorText: _error,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _orange),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _checking
                                  ? null
                                  : () => setState(() {
                                      _showPin = false;
                                      _error = null;
                                      _pinController.clear();
                                    }),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: _font,
                                  color: _brown,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _checking ? null : _submitPin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _checking
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Unlock',
                                      style: TextStyle(
                                        fontFamily: _font,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
