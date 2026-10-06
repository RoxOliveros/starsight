import 'dart:async';

import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Public entry point — call this from any level screen.
class StarsightSetupTutorial {
  static const _prefsKeyPrefix = 'starsight_setup_seen_';

  static bool isSessionCalibrated = false;

  /// Shows the setup tutorial if the user hasn't seen it for [levelId] yet.
  /// If already seen, [onDone] fires immediately with no dialog.
  static Future<void> show(
    BuildContext context, {
    required String levelId,
    required VoidCallback onDone,
    bool forceShow = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$levelId';
    final alreadySeen = prefs.getBool(key) ?? false;

    if (!forceShow && alreadySeen) {
      onDone();
      return;
    }

    // Small delay before the tutorial pops in, so it doesn't feel abrupt
    // right after the level screen finishes loading.
    await Future.delayed(const Duration(milliseconds: 400));

    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _StarsightSetupDialog(
          onSkip: () async {
            await prefs.setBool(key, true);
            Navigator.of(context).pop();
            onDone();
          },
          onFinish: () async {
            await prefs.setBool(key, true);
            Navigator.of(context).pop();
            onDone();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Pop/bounce effect: scale up from slightly smaller, with a fade in.
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  /// Call from Parents Area to let them redo the tutorial for a level.
  static Future<void> reset(String levelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsKeyPrefix$levelId');
  }
}

class _StarsightSetupDialog extends StatefulWidget {
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  const _StarsightSetupDialog({required this.onSkip, required this.onFinish});

  @override
  State<_StarsightSetupDialog> createState() => _StarsightSetupDialogState();
}

class _StarsightSetupDialogState extends State<_StarsightSetupDialog>
    with AiCameraMixin {
  // Current tutorial page
  int currentPage = 0;

  bool _isCalibrationDone = StarsightSetupTutorial.isSessionCalibrated;

  @override
  void initState() {
    super.initState();
    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';

    onCalibrationComplete = () {
      if (mounted) {
        setState(() {
          _isCalibrationDone = true;
          StarsightSetupTutorial.isSessionCalibrated = true;
        });
      }
    };
  }

  @override
  void dispose() {
    disposeAiCamera();
    super.dispose();
  }

  void _goToPage(int page) {
    setState(() {
      currentPage = page;
    });

    if (page == 2) {
      if (StarsightSetupTutorial.isSessionCalibrated) {
        setState(() => _isCalibrationDone = true);
        // Start camera for the visual preview, but DO NOT wipe server memory!
        startAiCamera(captureInterval: const Duration(milliseconds: 900));
      } else {
        // First time this session: wipe server memory, then start camera
        resetCalibrationForNewChild().then((_) {
          if (mounted) {
            startAiCamera(captureInterval: const Duration(milliseconds: 900));
          }
        });
      }
    } else {
      disposeAiCamera();
    }
  }

  /// Status text that changes based on the real camera state.
  String? _statusText() {
    if (_isCalibrationDone) return null;
    if (!isFaceDetected) return 'PLEASE LOOK AT THE CAMERA...';
    return 'STARSIGHT IS GETTING TO KNOW YOUR CHILD...';
  }

  /// Camera preview with the loading spinner / check mark in the lower right.
  Widget _buildCameraStep() {
    Widget preview;

    if (isCameraInitialized && aiCameraController != null) {
      final aspect = aiCameraController!.value.aspectRatio;
      preview = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 100,
            height: 100 / aspect,
            child: CameraPreview(aiCameraController!),
          ),
        ),
      );
    } else {
      preview = const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFFD875),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black, child: preview),

        // Loading spinner -> check mark, lower right of the camera
        Positioned(
          right: 8,
          bottom: 8,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.elasticOut,
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _isCalibrationDone
                ? Container(
                    key: const ValueKey('check'),
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF12A100),
                      shape: BoxShape.circle,
                    ),
                    // Custom check with fully rounded ends and corners
                    child: CustomPaint(painter: _RoundCheckPainter()),
                  )
                : Container(
                    key: const ValueKey('loading'),
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD875),
                        width: 2,
                      ),
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final dialogWidth = (screenSize.width * 0.90).clamp(450.0, 620.0);
    final dialogHeight = dialogWidth / 1.80;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          children: [
            // The frame, centered on screen
            Center(
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/tutorial_frame.png'),
                    fit: BoxFit.fill,
                  ),
                ),

                // Content sits inside the frame's inner area.
                padding: EdgeInsets.symmetric(
                  horizontal: dialogWidth * 0.06,
                  vertical: dialogHeight * 0.12,
                ),

                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          currentPage == 2
                              ? (_isCalibrationDone
                                    ? "EVERYTHING IS SET!"
                                    : "LET'S CHECK YOUR CAMERA!")
                              : "LET'S SETUP STARSIGHT",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF6B4A2E),
                            letterSpacing: 0.5,
                          ),
                        ),

                        SizedBox(height: currentPage == 2 ? 15 : 0),
                        // IMAGE
                        Flexible(
                          flex: 1,
                          child: Transform.translate(
                            offset: const Offset(0, -5),
                            child: FractionallySizedBox(
                              widthFactor: currentPage == 2 ? 0.80 : 0.90,
                              heightFactor: currentPage == 2 ? .90 : 0.95,
                              child: Stack(
                                clipBehavior: Clip
                                    .none, // lets the status stick out of the camera
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: currentPage == 2
                                        ? _buildCameraStep()
                                        : Image.asset(
                                            currentPage == 0
                                                ? 'assets/images/step1.png'
                                                : 'assets/images/steptwo.png',
                                            fit: BoxFit.contain,
                                          ),
                                  ),

                                  // Status pill: only shows when there's a status for the current state
                                  if (currentPage == 2 &&
                                      !_isCalibrationDone &&
                                      _statusText() != null)
                                    Positioned(
                                      right: -25,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD875),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Text(
                                          _statusText()!,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontFamily: 'Fredoka',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            color: Color(0xFF6B4A2E),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // BOTTOM TEXT
                        if (currentPage == 2)
                          // Step 3: no text, just a small spacer
                          const SizedBox(height: 15)
                        else
                          Transform.translate(
                            offset: const Offset(0, -15),
                            child: Text(
                              currentPage == 0
                                  ? 'Place your phone in landscape mode on a stable table or phone stand. '
                                        '\nMake sure it stays steady and does not move or fall while your child is playing.'
                                  : 'Use a well-lit room with a clear background. '
                                        '\nMake sure there are no objects blocking the camera\'s view.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 11,
                                color: Color(0xFF6B4A2E),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // PREVIOUS BUTTON
            Positioned(
              left: (screenSize.width - dialogWidth) / 1.6 + dialogWidth * 0.04,
              top: (screenSize.height - dialogHeight) / 2 + dialogHeight * 0.40,
              child: GestureDetector(
                onTap: () {
                  if (currentPage > 0) {
                    _goToPage(currentPage - 1);
                  }
                },
                child: const Text(
                  '<',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B4A2E),
                  ),
                ),
              ),
            ),

            // NEXT BUTTON (pages 1 & 2)
            if (currentPage < 2)
              Positioned(
                right:
                    (screenSize.width - dialogWidth) / 1.6 + dialogWidth * 0.04,
                top:
                    (screenSize.height - dialogHeight) / 2 +
                    dialogHeight * 0.40,
                child: GestureDetector(
                  onTap: () {
                    _goToPage(currentPage + 1);
                  },
                  child: const Text(
                    '>',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B4A2E),
                    ),
                  ),
                ),
              ),

            // DOTS INDICATOR / LETS PLAY BUTTON
            Positioned(
              bottom:
                  (screenSize.height - dialogHeight) / .6 + dialogHeight * 0.07,
              left: 0,
              right: 0,
              child: (currentPage == 2 && _isCalibrationDone)
                  ? Center(
                      child: GestureDetector(
                        onTap: widget.onFinish,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD875),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            ' LETS PLAY! ',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF6B4A2E),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: currentPage == 0
                                ? const Color(0xFFFFD875)
                                : const Color(0xFFD0D0D0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: currentPage == 1
                                ? const Color(0xFFFFD875)
                                : const Color(0xFFD0D0D0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: currentPage == 2
                                ? const Color(0xFFFFD875)
                                : const Color(0xFFD0D0D0),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
            ),

            // SKIP button
            if (currentPage < 2)
              Positioned(
                top: 20,
                right: 20,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () {
                      _goToPage(2);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfdf8ec),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF775445),
                          width: 3,
                        ),
                      ),
                      child: const Text(
                        'SKIP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Fredoka',
                          color: Color(0xFF6B4A2E),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Draws a check mark with fully rounded line ends and corners.
class _RoundCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.72, size.height * 0.35);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
