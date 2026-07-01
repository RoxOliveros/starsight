import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'tutorial_prompt_card.dart';

/// The "How to Play" tutorial for the Sharing mini-game.
///
/// This is a thin content wrapper around the universal [TutorialPromptCard] —
/// all the shared layout/animation/audio-timing logic lives there so other
/// screens (lighting, etc.) can reuse it with their own content.
class SharingTutorialPrompt extends StatelessWidget {
  final VoidCallback? onClose;

  const SharingTutorialPrompt({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return TutorialPromptCard(
      title: 'How to Play!',
      instructionText: 'Drag the pancake and water to share with your friends!',
      demoVisual: const _SharingDemoVisual(),
      hintText: 'If they come back, tap the Cancel button!',
      hintImagePath: 'assets/images/objects/lumi/cancel_btn.png',
      // Plays as soon as the card appears, not after it's closed.
      audioAssetPath: 'audio/lumi_town/level5/sharing.wav',
      onClose: onClose,
    );
  }
}

/// The animated "pancake/water sliding toward a character" illustration.
/// Sized relative to the available width via [LayoutBuilder] so it never
/// overflows on narrow cards/screens.
class _SharingDemoVisual extends StatelessWidget {
  const _SharingDemoVisual();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        final foodWidth = (availableWidth * 0.17).clamp(40.0, 65.0);
        final waterWidth = foodWidth * 0.5;
        final itemSpacing = (availableWidth * 0.04).clamp(8.0, 14.0);
        final spacing = (availableWidth * 0.09).clamp(16.0, 32.0);
        final characterHeight = (availableWidth * 0.28).clamp(60.0, 95.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Draggable items moving right (simulated drag-and-drop demo).
            // Pancake sits on the left, water glass on the right.
            Flexible(
              child:
                  Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/images/objects/lumi/pancke_maple_syrup_butter.png',
                            width: foodWidth,
                          ),
                          SizedBox(width: itemSpacing),
                          Image.asset(
                            'assets/images/objects/lumi/water_glass.png',
                            width: waterWidth,
                          ),
                        ],
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .moveX(
                        begin: 0,
                        end: 70,
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeInOut,
                      )
                      .fadeOut(
                        delay: const Duration(milliseconds: 1500),
                        duration: const Duration(milliseconds: 500),
                      ),
            ),

            SizedBox(width: spacing),

            // Receiving character (e.g. Roxie)
            Flexible(
              child: Image.asset(
                'assets/images/characters/roxie_standing.png',
                height: characterHeight,
                errorBuilder: (ctx, err, st) => Icon(
                  Icons.person,
                  size: characterHeight,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
