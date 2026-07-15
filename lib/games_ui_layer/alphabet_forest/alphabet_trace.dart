import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_paint.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_pop.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../business_layer/forest_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_puzzle.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_hunt.dart';

import 'alphabet_game_ui.dart';

class TraceLevel {
  final String letterName;
  final String imagePath;
  final List<List<Offset>> strokes;

  TraceLevel({
    required this.letterName,
    required this.imagePath,
    required this.strokes,
  });
}

class AlphabetTraceScreen extends StatefulWidget {
  final String startingLetter;

  const AlphabetTraceScreen({super.key, required this.startingLetter});

  @override
  State<AlphabetTraceScreen> createState() => _AlphabetTraceScreenState();
}

class _AlphabetTraceScreenState extends State<AlphabetTraceScreen>
  with TofiReactionMixin {
  final AudioPlayer _player = AudioPlayer();

  @override
  AudioPlayer get tofiPlayer => _player;

  final GlobalKey _canvasKey = GlobalKey();
  int _currentLevelIndex = 0;

  // Tracking Progress
  int _currentStrokeIndex = 0;
  int _currentPointIndex = 0;
  List<List<Offset>> _denseStrokes = [];

  late List<TraceLevel> _levels;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Load the specific letter's strokes
    _loadLetter(widget.startingLetter);

    WidgetsBinding.instance.addPostFrameCallback((_) => _generateDensePaths());
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _player.dispose();
    super.dispose();
  }

  // --- THE DYNAMIC LETTER LOADER ---
  void _loadLetter(String letter) {
    switch (letter.toUpperCase()) {
      case 'A':
        _levels = [
          TraceLevel(
            letterName: "Big A",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.2), const Offset(0.2, 0.8)],
              [const Offset(0.5, 0.2), const Offset(0.8, 0.8)],
              [const Offset(0.35, 0.5), const Offset(0.65, 0.5)],
            ],
          ),
          TraceLevel(
            letterName: "Small a",
            imagePath: '',
            strokes: [
              [
                const Offset(0.70, 0.50),
                const Offset(0.50, 0.40),
                const Offset(0.40, 0.45),
                const Offset(0.30, 0.60),
                const Offset(0.45, 0.80),
                const Offset(0.65, 0.75),
                const Offset(0.70, 0.65),
              ],
              [const Offset(0.70, 0.35), const Offset(0.70, 0.85)],
            ],
          ),
        ];
        break;
      case 'B':
        _levels = [
          TraceLevel(
            letterName: "Big B",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.7, 0.35),
                const Offset(0.6, 0.5),
                const Offset(0.3, 0.5),
              ], // Top Loop
              [
                const Offset(0.3, 0.5),
                const Offset(0.65, 0.5),
                const Offset(0.75, 0.65),
                const Offset(0.65, 0.8),
                const Offset(0.3, 0.8),
              ], // Bot Loop
            ],
          ),
          TraceLevel(
            letterName: "Small b",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [
                const Offset(0.3, 0.5),
                const Offset(0.6, 0.5),
                const Offset(0.7, 0.65),
                const Offset(0.6, 0.8),
                const Offset(0.3, 0.8),
              ], // Loop
            ],
          ),
        ];
        break;
      case 'C':
        _levels = [
          TraceLevel(
            letterName: "Big C",
            imagePath: '',
            strokes: [
              [
                const Offset(0.7, 0.25),
                const Offset(0.5, 0.2),
                const Offset(0.3, 0.4),
                const Offset(0.3, 0.6),
                const Offset(0.5, 0.8),
                const Offset(0.7, 0.75),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small c",
            imagePath: '',
            strokes: [
              [
                const Offset(0.65, 0.55),
                const Offset(0.5, 0.5),
                const Offset(0.35, 0.6),
                const Offset(0.35, 0.7),
                const Offset(0.5, 0.8),
                const Offset(0.65, 0.75),
              ],
            ],
          ),
        ];
        break;
      case 'D':
        _levels = [
          TraceLevel(
            letterName: "Big D",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.75, 0.5),
                const Offset(0.6, 0.8),
                const Offset(0.3, 0.8),
              ], // Big Loop
            ],
          ),
          TraceLevel(
            letterName: "Small d",
            imagePath: '',
            strokes: [
              [
                const Offset(0.6, 0.5),
                const Offset(0.4, 0.5),
                const Offset(0.3, 0.65),
                const Offset(0.4, 0.8),
                const Offset(0.6, 0.8),
              ], // Loop
              [const Offset(0.6, 0.2), const Offset(0.6, 0.8)], // Vertical
            ],
          ),
        ];
        break;
      case 'E':
        _levels = [
          TraceLevel(
            letterName: "Big E",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [const Offset(0.3, 0.2), const Offset(0.65, 0.2)], // Top
              [const Offset(0.3, 0.5), const Offset(0.55, 0.5)], // Mid
              [const Offset(0.3, 0.8), const Offset(0.65, 0.8)], // Bot
            ],
          ),
          TraceLevel(
            letterName: "Small e",
            imagePath: '',
            strokes: [
              [
                const Offset(0.35, 0.65),
                const Offset(0.65, 0.65),
                const Offset(0.65, 0.5),
                const Offset(0.5, 0.45),
                const Offset(0.35, 0.55),
                const Offset(0.35, 0.75),
                const Offset(0.5, 0.85),
                const Offset(0.7, 0.75),
              ],
            ],
          ),
        ];
        break;
      case 'F':
        _levels = [
          TraceLevel(
            letterName: "Big F",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [const Offset(0.3, 0.2), const Offset(0.65, 0.2)], // Top
              [const Offset(0.3, 0.5), const Offset(0.55, 0.5)], // Mid
            ],
          ),
          TraceLevel(
            letterName: "Small f",
            imagePath: '',
            strokes: [
              // Stroke 1: The top hook and straight line down
              [
                const Offset(0.60, 0.25), // Start at top right of the hook
                const Offset(0.50, 0.15), // Curve up to the top middle
                const Offset(0.40, 0.25), // Curve down to the left
                const Offset(0.40, 0.85), // Go straight down to the bottom
              ],
              // Stroke 2: The middle crossbar
              [
                const Offset(0.25, 0.45), // Start left of the stem
                const Offset(0.55, 0.45), // Cross over to the right
              ],
            ],
          ),
        ];
        break;
      case 'G':
        _levels = [
          TraceLevel(
            letterName: "Big G",
            imagePath: '',
            strokes: [
              [
                const Offset(0.7, 0.25),
                const Offset(0.5, 0.2),
                const Offset(0.3, 0.4),
                const Offset(0.3, 0.6),
                const Offset(0.5, 0.8),
                const Offset(0.7, 0.7),
                const Offset(0.7, 0.55),
                const Offset(0.5, 0.55),
              ], // C-curve into horizontal
            ],
          ),
          TraceLevel(
            letterName: "Small g",
            imagePath: '',
            strokes: [
              [
                const Offset(0.6, 0.4),
                const Offset(0.4, 0.4),
                const Offset(0.3, 0.55),
                const Offset(0.4, 0.7),
                const Offset(0.6, 0.7),
                const Offset(0.6, 0.4),
              ], // Top circle
              [
                const Offset(0.6, 0.4),
                const Offset(0.6, 0.8),
                const Offset(0.5, 0.9),
                const Offset(0.35, 0.85),
              ], // Stem & hook
            ],
          ),
        ];
        break;
      case 'H':
        _levels = [
          TraceLevel(
            letterName: "Big H",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Left vertical
              [
                const Offset(0.7, 0.2),
                const Offset(0.7, 0.8),
              ], // Right vertical
              [const Offset(0.3, 0.5), const Offset(0.7, 0.5)], // Crossbar
            ],
          ),
          TraceLevel(
            letterName: "Small h",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Tall vertical
              [
                const Offset(0.3, 0.5),
                const Offset(0.5, 0.45),
                const Offset(0.65, 0.55),
                const Offset(0.65, 0.8),
              ], // Arch down
            ],
          ),
        ];
        break;
      case 'I':
        _levels = [
          TraceLevel(
            letterName: "Big I",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.2),
                const Offset(0.7, 0.2),
              ], // Top horizontal
              [
                const Offset(0.3, 0.8),
                const Offset(0.7, 0.8),
              ], // Bottom horizontal
              [
                const Offset(0.5, 0.2),
                const Offset(0.5, 0.8),
              ], // Middle vertical
            ],
          ),
          TraceLevel(
            letterName: "Small i",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.4), const Offset(0.5, 0.8)], // Stem
              [
                const Offset(0.5, 0.25),
                const Offset(0.5, 0.26),
              ], // Dot (tiny stroke)
            ],
          ),
        ];
        break;
      case 'J':
        _levels = [
          TraceLevel(
            letterName: "Big J",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.2),
                const Offset(0.7, 0.2),
              ], // Top horizontal
              [
                const Offset(0.5, 0.2),
                const Offset(0.5, 0.7),
                const Offset(0.4, 0.8),
                const Offset(0.3, 0.7),
              ], // Stem & hook
            ],
          ),
          TraceLevel(
            letterName: "Small j",
            imagePath: '',
            strokes: [
              [
                const Offset(0.5, 0.4),
                const Offset(0.5, 0.8),
                const Offset(0.4, 0.9),
                const Offset(0.3, 0.85),
              ], // Stem & hook
              [const Offset(0.5, 0.25), const Offset(0.5, 0.26)], // Dot
            ],
          ),
        ];
        break;
      case 'K':
        _levels = [
          TraceLevel(
            letterName: "Big K",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)],
              [const Offset(0.7, 0.2), const Offset(0.3, 0.5)],
              [const Offset(0.3, 0.5), const Offset(0.7, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small k",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)],
              [const Offset(0.6, 0.45), const Offset(0.3, 0.6)],
              [const Offset(0.3, 0.6), const Offset(0.6, 0.8)],
            ],
          ),
        ];
        break;
      case 'L':
        _levels = [
          TraceLevel(
            letterName: "Big L",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.2),
                const Offset(0.3, 0.8),
                const Offset(0.7, 0.8),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small l",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.2), const Offset(0.5, 0.8)],
            ],
          ),
        ];
        break;
      case 'M':
        _levels = [
          TraceLevel(
            letterName: "Big M",
            imagePath: '',
            strokes: [
              [
                const Offset(0.2, 0.8),
                const Offset(0.2, 0.2),
                const Offset(0.5, 0.5),
                const Offset(0.8, 0.2),
                const Offset(0.8, 0.8),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small m",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.4), const Offset(0.25, 0.8)],
              [
                const Offset(0.25, 0.5),
                const Offset(0.5, 0.4),
                const Offset(0.5, 0.8),
              ],
              [
                const Offset(0.5, 0.5),
                const Offset(0.75, 0.4),
                const Offset(0.75, 0.8),
              ],
            ],
          ),
        ];
        break;
      case 'N':
        _levels = [
          TraceLevel(
            letterName: "Big N",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.8),
                const Offset(0.3, 0.2),
                const Offset(0.7, 0.8),
                const Offset(0.7, 0.2),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small n",
            imagePath: '',
            strokes: [
              [const Offset(0.35, 0.4), const Offset(0.35, 0.8)],
              [
                const Offset(0.35, 0.5),
                const Offset(0.65, 0.4),
                const Offset(0.65, 0.8),
              ],
            ],
          ),
        ];
      case 'O':
        _levels = [
          TraceLevel(
            letterName: "Big O",
            imagePath: '',
            strokes: [
              [
                const Offset(0.5, 0.2),
                const Offset(0.3, 0.3),
                const Offset(0.3, 0.7),
                const Offset(0.5, 0.8),
                const Offset(0.7, 0.7),
                const Offset(0.7, 0.3),
                const Offset(0.5, 0.2),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small o",
            imagePath: '',
            strokes: [
              [
                const Offset(0.5, 0.4),
                const Offset(0.35, 0.5),
                const Offset(0.35, 0.7),
                const Offset(0.5, 0.8),
                const Offset(0.65, 0.7),
                const Offset(0.65, 0.5),
                const Offset(0.5, 0.4),
              ],
            ],
          ),
        ];
        break;

      case 'P':
        _levels = [
          TraceLevel(
            letterName: "Big P",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Line down
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.7, 0.35),
                const Offset(0.6, 0.5),
                const Offset(0.3, 0.5),
              ], // Top loop
            ],
          ),
          TraceLevel(
            letterName: "Small p",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.4),
                const Offset(0.3, 0.95),
              ], // Line drops below baseline
              [
                const Offset(0.3, 0.4),
                const Offset(0.6, 0.4),
                const Offset(0.7, 0.55),
                const Offset(0.6, 0.7),
                const Offset(0.3, 0.7),
              ], // Small loop
            ],
          ),
        ];
        break;

      case 'Q':
        _levels = [
          TraceLevel(
            letterName: "Big Q",
            imagePath: '',
            strokes: [
              [
                const Offset(0.5, 0.2),
                const Offset(0.3, 0.3),
                const Offset(0.3, 0.7),
                const Offset(0.5, 0.8),
                const Offset(0.7, 0.7),
                const Offset(0.7, 0.3),
                const Offset(0.5, 0.2),
              ], // Circle
              [const Offset(0.55, 0.65), const Offset(0.75, 0.85)], // Tail
            ],
          ),
          TraceLevel(
            letterName: "Small q",
            imagePath: '',
            strokes: [
              [
                const Offset(0.65, 0.4),
                const Offset(0.5, 0.4),
                const Offset(0.35, 0.55),
                const Offset(0.5, 0.7),
                const Offset(0.65, 0.7),
              ], // Left circle
              [const Offset(0.65, 0.4), const Offset(0.65, 0.95)], // Line down
            ],
          ),
        ];
        break;

      case 'R':
        _levels = [
          TraceLevel(
            letterName: "Big R",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Line down
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.7, 0.35),
                const Offset(0.6, 0.5),
                const Offset(0.3, 0.5),
              ], // Loop
              [const Offset(0.3, 0.5), const Offset(0.7, 0.8)], // Diagonal leg
            ],
          ),
          TraceLevel(
            letterName: "Small r",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.4), const Offset(0.3, 0.8)], // Line down
              [
                const Offset(0.3, 0.55),
                const Offset(0.45, 0.4),
                const Offset(0.6, 0.4),
              ], // Small arc
            ],
          ),
        ];
        break;

      case 'S':
        _levels = [
          TraceLevel(
            letterName: "Big S",
            imagePath: '',
            strokes: [
              [
                const Offset(0.7, 0.3),
                const Offset(0.5, 0.2),
                const Offset(0.3, 0.35),
                const Offset(0.5, 0.5),
                const Offset(0.7, 0.65),
                const Offset(0.5, 0.8),
                const Offset(0.3, 0.7),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small s",
            imagePath: '',
            strokes: [
              [
                const Offset(0.65, 0.45),
                const Offset(0.5, 0.4),
                const Offset(0.35, 0.5),
                const Offset(0.5, 0.6),
                const Offset(0.65, 0.7),
                const Offset(0.5, 0.8),
                const Offset(0.35, 0.75),
              ],
            ],
          ),
        ];
        break;

      case 'T':
        _levels = [
          TraceLevel(
            letterName: "Big T",
            imagePath: '',
            strokes: [
              [const Offset(0.2, 0.2), const Offset(0.8, 0.2)], // Top bar
              [const Offset(0.5, 0.2), const Offset(0.5, 0.8)], // Stem down
            ],
          ),
          TraceLevel(
            letterName: "Small t",
            imagePath: '',
            strokes: [
              [
                const Offset(0.5, 0.2),
                const Offset(0.5, 0.75),
                const Offset(0.6, 0.8),
              ], // Stem with bottom hook
              [const Offset(0.3, 0.45), const Offset(0.7, 0.45)], // Cross bar
            ],
          ),
        ];
        break;

      case 'U':
        _levels = [
          TraceLevel(
            letterName: "Big U",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.2),
                const Offset(0.3, 0.65),
                const Offset(0.5, 0.8),
                const Offset(0.7, 0.65),
                const Offset(0.7, 0.2),
              ], // Single large curve
            ],
          ),
          TraceLevel(
            letterName: "Small u",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.4),
                const Offset(0.3, 0.7),
                const Offset(0.5, 0.8),
                const Offset(0.7, 0.7),
                const Offset(0.7, 0.4),
              ], // Small cup
              [const Offset(0.7, 0.4), const Offset(0.7, 0.8)], // Stem down
            ],
          ),
        ];
        break;
      default:
        // Fallback to A if something goes wrong
        _levels = [
          TraceLevel(
            letterName: "Big A",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.2), const Offset(0.2, 0.8)],
              [const Offset(0.5, 0.2), const Offset(0.8, 0.8)],
              [const Offset(0.35, 0.5), const Offset(0.65, 0.5)],
            ],
          ),
        ];
    }
  }

  void _generateDensePaths() {
    final RenderBox? renderBox =
    _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size size = renderBox.size;
    List<List<Offset>> newDenseStrokes = [];

    for (var stroke in _levels[_currentLevelIndex].strokes) {
      final pts = stroke
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();

      if (pts.length < 2) {
        newDenseStrokes.add(pts);
        continue;
      }

      List<Offset> densePoints = [];
      for (int i = 0; i < pts.length - 1; i++) {
        final p0 = i == 0 ? pts[i] : pts[i - 1];              // ADD: neighbor points for the curve
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];

        final distance = (p2 - p1).distance;
        final steps = (distance / 5.0).ceil().clamp(1, 999);

        for (int j = 0; j <= steps; j++) {
          final t = j / steps;
          densePoints.add(_catmullRom(p0, p1, p2, p3, t));      // CHANGED from straight lerp
        }
      }
      newDenseStrokes.add(densePoints);
    }

    setState(() {
      _denseStrokes = newDenseStrokes;
    });
  }

// ADD this helper method (same technique as number_tracing_widget.dart)
  Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    final x = 0.5 *
        ((2 * p1.dx) +
            (p2.dx - p0.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (3 * p1.dx - p0.dx - 3 * p2.dx + p3.dx) * t3);
    final y = 0.5 *
        ((2 * p1.dy) +
            (p2.dy - p0.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (3 * p1.dy - p0.dy - 3 * p2.dy + p3.dy) * t3);
    return Offset(x, y);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    Offset dragPos = details.localPosition;
    List<Offset> currentStroke = _denseStrokes[_currentStrokeIndex];

    if (_currentPointIndex < currentStroke.length) {
      Offset target = currentStroke[_currentPointIndex];
      double distance = sqrt(
        pow(dragPos.dx - target.dx, 2) + pow(dragPos.dy - target.dy, 2),
      );

      if (distance < 40.0) {
        setState(() {
          while (_currentPointIndex < currentStroke.length &&
              sqrt(
                    pow(dragPos.dx - currentStroke[_currentPointIndex].dx, 2) +
                        pow(
                          dragPos.dy - currentStroke[_currentPointIndex].dy,
                          2,
                        ),
                  ) <
                  40.0) {
            _currentPointIndex++;
          }
        });

        if (_currentPointIndex >= currentStroke.length) {
          _moveToNextStroke();
        }
      }
    }
  }

  void _moveToNextStroke() {
    setState(() {
      _currentStrokeIndex++;
      _currentPointIndex = 0;
    });

    if (_currentStrokeIndex >= _denseStrokes.length) {
      _showSuccessDialog();
    }
  }

  void _resetBoard() {
    setState(() {
      _currentStrokeIndex = 0;
      _currentPointIndex = 0;
    });
  }

  Future<void> _showSuccessDialog() async {
    await showTofiReaction(TofiState.correct);

    bool isLastSubLevel = _currentLevelIndex == _levels.length - 1;

    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: 'assets/images/characters/dog.png',
          closeButtonColor: ForestColorTheme.mediumseagreen,

          onNext: () {
            Navigator.pop(context); // Close the dialog

            if (!isLastSubLevel) {
              setState(() {
                _resetBoard();
                _currentLevelIndex++;
                _generateDensePaths();
              });
            } else {
              // --- SMART MINI-GAME ROUTER ---
              String letter = widget.startingLetter.toUpperCase();

              // 1. Water Color: A, E, H, L
              if (['A', 'E', 'H', 'L'].contains(letter)) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlphabetPaintScreen(letter: letter),
                  ),
                );
              }
              // 2. Pop: B, F, I, M
              else if (['B', 'F', 'I', 'M'].contains(letter)) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetPopScreen(targetLetter: letter),
                  ),
                );
              }
              // 3. Puzzle: C, G, J, N
              else if (['C', 'G', 'J', 'N'].contains(letter)) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetPuzzleScreen(letter: letter),
                  ),
                );
              }
              // 4. Hunt: D, K
              else if (['D', 'K'].contains(letter)) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetHuntScreen(letter: letter),
                  ),
                );
              }
              // Fallback
              else {
                Navigator.pop(context);
              }
            }
          },
          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _resetBoard(); // Restart current trace
            });
          },

          onBack: () {
            Navigator.pop(context);
            Navigator.pop(context); // Go back to Map
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ForestBackground(
        child:
        Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 80,
                  child: Stack(
                    children: [
                      const Positioned(
                        top: 25,
                        left: 20,
                        child: ForestBackButton(),
                      ),

                      Positioned(
                        top: 25,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ForestInstructionBanner(
                            text: 'Trace ${_levels[_currentLevelIndex]
                                .letterName}',
                          ),
                        ),
                      ),

                      Positioned(
                        top: 25,
                        right: 20,
                        child: ForestLevelBadge(
                          level: ForestProgressService.levelNumberForLetter(
                            widget.startingLetter,
                          ) ??
                              1,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Container(
                          key: _canvasKey,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: ForestColorTheme.lightgreen,
                              width: 4,
                            ),
                          ),
                          child: Stack(
                            children: [
                              GestureDetector(
                                onPanUpdate: _onPanUpdate,
                                child: CustomPaint(
                                  painter: GuidedTracePainter(
                                    denseStrokes: _denseStrokes,
                                    currentStrokeIndex: _currentStrokeIndex,
                                    currentPointIndex: _currentPointIndex,
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            buildTofi(context),
          ],
        ),
      ),
    );
  }
}

class GuidedTracePainter extends CustomPainter {
  final List<List<Offset>> denseStrokes;
  final int currentStrokeIndex;
  final int currentPointIndex;

  GuidedTracePainter({
    required this.denseStrokes,
    required this.currentStrokeIndex,
    required this.currentPointIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (denseStrokes.isEmpty) return;

    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );

    final bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 35.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < denseStrokes.length; i++) {
      var stroke = denseStrokes[i];
      if (stroke.isEmpty) continue;

      Path bgPath = Path();
      bgPath.moveTo(stroke[0].dx, stroke[0].dy);
      for (int j = 1; j < stroke.length; j++) {
        bgPath.lineTo(stroke[j].dx, stroke[j].dy);
      }
      canvas.drawPath(bgPath, bgPaint);
    }

    canvas.restore();

    final fillPaint = Paint()
      ..color = ForestColorTheme.mediumseagreen
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 30.0
      ..style = PaintingStyle.stroke;

    final guidePaint = Paint()
      ..color = ForestColorTheme.darkseagreen
      ..style = PaintingStyle.fill;

    for (int i = 0; i < denseStrokes.length; i++) {
      var stroke = denseStrokes[i];
      if (stroke.isEmpty) continue;

      if (i < currentStrokeIndex) {
        Path fillPath = Path();
        fillPath.moveTo(stroke[0].dx, stroke[0].dy);
        for (int j = 1; j < stroke.length; j++) {
          fillPath.lineTo(stroke[j].dx, stroke[j].dy);
        }
        canvas.drawPath(fillPath, fillPaint);
      } else if (i == currentStrokeIndex) {
        if (currentPointIndex > 0) {
          Path fillPath = Path();
          fillPath.moveTo(stroke[0].dx, stroke[0].dy);
          for (int j = 1; j < currentPointIndex; j++) {
            fillPath.lineTo(stroke[j].dx, stroke[j].dy);
          }
          canvas.drawPath(fillPath, fillPaint);
        }

        if (currentPointIndex < stroke.length) {
          canvas.drawCircle(stroke[currentPointIndex], 20.0, guidePaint);

          final iconPaint = Paint()
            ..color = Colors.white
            ..strokeWidth = 4.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          Offset center = stroke[currentPointIndex];
          canvas.drawLine(
            Offset(center.dx - 5, center.dy),
            Offset(center.dx, center.dy + 5),
            iconPaint,
          );
          canvas.drawLine(
            Offset(center.dx, center.dy + 5),
            Offset(center.dx + 8, center.dy - 6),
            iconPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuidedTracePainter oldDelegate) => true;
}
