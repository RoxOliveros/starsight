import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

/// A universal "How to Play" tutorial overlay.
///
/// This is content-agnostic — it only knows about layout, animation timing,
/// and the fade/slide "hint" reveal. Every screen (sharing, lighting, etc.)
/// supplies its own title, instructions, demo visual, hint, and audio.
///
/// Usage:
/// ```dart
/// TutorialPromptCard(
///   title: 'How to Play!',
///   instructionText: 'Drag the pancake and water to share with your friends!',
///   demoVisual: MyDemoRow(...),
///   hintText: 'If they come back, tap the Cancel button!',
///   hintImagePath: 'assets/images/objects/lumi/cancel_btn.png',
///   audioAssetPath: 'audio/lumi_town/level5/sharing.wav',
///   onClose: _handleTutorialClose,
/// )
/// ```
class TutorialPromptCard extends StatefulWidget {
  final String title;
  final String instructionText;

  /// The animated illustration explaining the mechanic (e.g. items sliding
  /// toward a character). Pass null to skip this section entirely.
  final Widget? demoVisual;

  /// Optional hint shown after [hintDelay] (e.g. "tap Cancel if they come back").
  /// Both [hintText] and [hintImagePath] must be provided together, or omit both.
  final String? hintText;
  final String? hintImagePath;
  final Duration hintDelay;

  /// Audio asset to play as soon as the card appears. Pass null for silence.
  final String? audioAssetPath;

  final VoidCallback? onClose;

  final bool autoCloseOnAudioComplete;

  const TutorialPromptCard({
    super.key,
    required this.title,
    required this.instructionText,
    this.demoVisual,
    this.hintText,
    this.hintImagePath,
    this.hintDelay = const Duration(seconds: 8),
    this.audioAssetPath,
    this.onClose,
    this.autoCloseOnAudioComplete = false,
  }) : assert(
         (hintText == null) == (hintImagePath == null),
         'hintText and hintImagePath must be provided together',
       );

  @override
  State<TutorialPromptCard> createState() => _TutorialPromptCardState();
}

class _TutorialPromptCardState extends State<TutorialPromptCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showHint = false;
  Timer? _hintTimer;

  StreamSubscription<void>? _audioCompleteSubscription;

  @override
  void initState() {
    super.initState();

    // Play instructional/round audio immediately when the prompt appears.
    final audioPath = widget.audioAssetPath;
    if (audioPath != null) {
      _audioPlayer.play(AssetSource(audioPath));

      if (widget.autoCloseOnAudioComplete && widget.onClose != null) {
        _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            widget.onClose!(); // Auto-dismiss the tutorial when audio ends!
          }
        });
      }
    }

    if (widget.hintText != null) {
      _hintTimer = Timer(widget.hintDelay, () {
        if (mounted) {
          setState(() {
            _showHint = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _audioCompleteSubscription?.cancel();
    _hintTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Card is 85% of screen width, capped at 450 — but never wider than the
    // screen minus a small safety margin, so it works on tiny/foldable
    // screens too instead of overflowing.
    final cardWidth = (screenSize.width * 0.85)
        .clamp(0, screenSize.width - 24)
        .clamp(0, 450)
        .toDouble();

    return Container(
      // Semi-transparent dark background matching other prompt cards
      // (e.g. LightingPromptCard) so overlays look consistent app-wide.
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: cardWidth,
            maxHeight: screenSize.height * 0.9,
          ),
          child: Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7EB),
              borderRadius: BorderRadius.circular(30.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 28.0,
                  ),
                  // Swaps the "how to play" instructions for the "tap
                  // Cancel" hint after [hintDelay] instead of showing both
                  // at once — keeps the card compact and un-scrollable.
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: (_showHint && widget.hintText != null)
                        ? _HintOnlyContent(
                            key: const ValueKey('hint'),
                            hintText: widget.hintText!,
                            hintImagePath: widget.hintImagePath!,
                            cardWidth: cardWidth,
                          )
                        : Column(
                            key: const ValueKey('howToPlay'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                  color: Color(0xFFE8A037),
                                ),
                              ),
                              const SizedBox(height: 16),

                              Text(
                                widget.instructionText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5E463E),
                                ),
                              ),

                              if (widget.demoVisual != null) ...[
                                const SizedBox(height: 16),
                                widget.demoVisual!,
                              ],
                            ],
                          ),
                  ),
                ),

                // Close Button (Top Right) styled identically across all
                // prompt cards.
                if (widget.onClose != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF5F7199).withValues(alpha: 0.5),
                      iconSize: 28,
                      onPressed: () {
                        // Stop audio immediately if closed early.
                        _audioPlayer.stop();
                        widget.onClose!();
                      },
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

/// Replaces the "how to play" instructions once [TutorialPromptCard.hintDelay]
/// elapses — the whole card becomes just this reminder instead of stacking
/// it beneath the original content.
class _HintOnlyContent extends StatelessWidget {
  final String hintText;
  final String hintImagePath;
  final double cardWidth;

  const _HintOnlyContent({
    super.key,
    required this.hintText,
    required this.hintImagePath,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Hint image scales with the card instead of a fixed pixel width, so it
    // never overflows on narrow cards.
    final hintImageWidth = (cardWidth * 0.18).clamp(48.0, 80.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hintText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD32F2F),
          ),
        ),
        const SizedBox(height: 14),
        Image.asset(hintImagePath, width: hintImageWidth)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.15, 1.15),
              duration: const Duration(milliseconds: 800),
            ),
      ],
    );
  }
}
