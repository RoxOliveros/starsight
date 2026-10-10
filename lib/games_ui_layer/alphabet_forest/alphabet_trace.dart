import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/forest_database_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_minigame_pop.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../business_layer/forest_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_minigame_puzzle.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_minigame_hunt.dart';
import 'alphabet_game_ui.dart';
import 'alphabet_minigame_fall.dart';
import 'alphabet_minigame_find.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final String letter;

  const AlphabetTraceScreen({super.key, required this.letter});

  @override
  State<AlphabetTraceScreen> createState() => _AlphabetTraceScreenState();
}

class _AlphabetTraceScreenState extends State<AlphabetTraceScreen>
    with TofiReactionMixin, AiCameraMixin, AppAudioLifecycleMixin<AlphabetTraceScreen> {

  final AudioPlayer _player = AudioPlayer();
  final GameTapTracker _tapTracker = GameTapTracker();
  final GlobalKey _canvasKey = GlobalKey();

  @override
  AudioPlayer get tofiPlayer => _player;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_player];

  int _currentLevelIndex = 0;
  int _currentStrokeIndex = 0;
  int _currentPointIndex = 0;

  int _nextMiniGame() {
    if (_miniGameIndex >= _miniGameQueue.length) {
      _miniGameQueue.shuffle(_random);
      _miniGameIndex = 0;
    }

    return _miniGameQueue[_miniGameIndex++];
  }

  List<List<Offset>> _denseStrokes = [];
  late List<TraceLevel> _levels;

  static final Random _random = Random();
  static List<int> _miniGameQueue = [];
  static int _miniGameIndex = 0;
  static const String _traceInstructionWav = 'audio/alphabet_forest/trace_letter_instruction.wav';

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _awaitingLift = false;
  bool _touchValid = false;
  bool _audioFinished = false;
  bool _isDotStroke(List<Offset> stroke) => stroke.length <= 3;

  Size _lastCanvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // child's calibration separate from everyone else's.
    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera(); // <-- Start the camera
    _tapTracker.startSession();

    // Lighting card can reappear later if the face is lost again mid-play.
    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };
    if (_miniGameQueue.isEmpty) {
      _miniGameQueue = List.generate(5, (i) => i);
      _miniGameQueue.shuffle(_random);
    }

    _loadLetter(widget.letter);
    _playInstructionThenLetter();
  }

  Future<void> _playInstructionThenLetter() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _player,
        _traceInstructionWav,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      await playVoiceRestartingOnFaceLoss(
        _player,
        'audio/alphabet_forest/sound_effects/sound_${widget.letter.toLowerCase()}.wav',
      );
    } finally {
      if (mounted) setState(() => _audioFinished = true);
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    OrientationService.setLandscape();
    _player.dispose();
    super.dispose();
  }

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
                const Offset(0.66, 0.48),
                const Offset(0.56, 0.41),
                const Offset(0.44, 0.42),
                const Offset(0.35, 0.52),
                const Offset(0.34, 0.66),
                const Offset(0.42, 0.77),
                const Offset(0.54, 0.80),
                const Offset(0.66, 0.74),
              ],
              [const Offset(0.66, 0.40), const Offset(0.66, 0.80)],
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
              [const Offset(0.34, 0.20), const Offset(0.34, 0.80)],
              [
                const Offset(0.34, 0.50),
                const Offset(0.42, 0.42),
                const Offset(0.54, 0.40),
                const Offset(0.64, 0.48),
                const Offset(0.67, 0.60),
                const Offset(0.64, 0.72),
                const Offset(0.54, 0.80),
                const Offset(0.42, 0.78),
                const Offset(0.34, 0.70),
              ],
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
                const Offset(0.70, 0.30),
                const Offset(0.60, 0.22),
                const Offset(0.48, 0.20),
                const Offset(0.37, 0.28),
                const Offset(0.31, 0.50),
                const Offset(0.37, 0.72),
                const Offset(0.48, 0.80),
                const Offset(0.60, 0.78),
                const Offset(0.70, 0.70),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small c",
            imagePath: '',
            strokes: [
              [
                const Offset(0.64, 0.48),
                const Offset(0.56, 0.42),
                const Offset(0.46, 0.41),
                const Offset(0.38, 0.47),
                const Offset(0.34, 0.60),
                const Offset(0.38, 0.73),
                const Offset(0.46, 0.79),
                const Offset(0.56, 0.78),
                const Offset(0.64, 0.72),
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
                const Offset(0.66, 0.48),
                const Offset(0.56, 0.41),
                const Offset(0.44, 0.42),
                const Offset(0.35, 0.52),
                const Offset(0.34, 0.66),
                const Offset(0.42, 0.77),
                const Offset(0.54, 0.80),
                const Offset(0.66, 0.74),
              ],
              [const Offset(0.66, 0.20), const Offset(0.66, 0.80)],
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
                const Offset(0.34, 0.60),
                const Offset(0.50, 0.60),
                const Offset(0.66, 0.60),
                const Offset(0.63, 0.48),
                const Offset(0.52, 0.41),
                const Offset(0.40, 0.45),
                const Offset(0.33, 0.60),
                const Offset(0.38, 0.74),
                const Offset(0.50, 0.80),
                const Offset(0.64, 0.75),
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
              [
                const Offset(0.60, 0.25),
                const Offset(0.50, 0.15),
                const Offset(0.40, 0.25),
                const Offset(0.40, 0.85),
              ],
              [
                const Offset(0.25, 0.45),
                const Offset(0.55, 0.45),
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
                const Offset(0.70, 0.30),
                const Offset(0.60, 0.22),
                const Offset(0.48, 0.20),
                const Offset(0.37, 0.28),
                const Offset(0.31, 0.50),
                const Offset(0.37, 0.72),
                const Offset(0.48, 0.80),
                const Offset(0.60, 0.78),
                const Offset(0.69, 0.70),
                const Offset(0.70, 0.56),
                const Offset(0.60, 0.55),
                const Offset(0.52, 0.55),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small g",
            imagePath: '',
            strokes: [
              [
                const Offset(0.66, 0.36),
                const Offset(0.56, 0.29),
                const Offset(0.44, 0.30),
                const Offset(0.35, 0.40),
                const Offset(0.34, 0.54),
                const Offset(0.42, 0.65),
                const Offset(0.54, 0.68),
                const Offset(0.66, 0.62),
              ],
              [
                const Offset(0.66, 0.28),
                const Offset(0.66, 0.70),
                const Offset(0.60, 0.80),
                const Offset(0.48, 0.83),
                const Offset(0.38, 0.78),
              ],
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
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)],
              [const Offset(0.3, 0.8), const Offset(0.7, 0.8)],
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
              [const Offset(0.20, 0.8), const Offset(0.20, 0.2)],
              [const Offset(0.20, 0.2), const Offset(0.50, 0.58)],
              [const Offset(0.50, 0.58), const Offset(0.80, 0.2)],
              [const Offset(0.80, 0.2), const Offset(0.80, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small m",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.40), const Offset(0.25, 0.80)],
              [
                const Offset(0.25, 0.56),
                const Offset(0.29, 0.46),
                const Offset(0.37, 0.41),
                const Offset(0.45, 0.46),
                const Offset(0.50, 0.56),
                const Offset(0.50, 0.80),
              ],
              [
                const Offset(0.50, 0.56),
                const Offset(0.54, 0.46),
                const Offset(0.62, 0.41),
                const Offset(0.70, 0.46),
                const Offset(0.75, 0.56),
                const Offset(0.75, 0.80),
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
              [const Offset(0.30, 0.8), const Offset(0.30, 0.2)],
              [const Offset(0.30, 0.2), const Offset(0.70, 0.8)],
              [const Offset(0.70, 0.8), const Offset(0.70, 0.2)],
            ],
          ),
          TraceLevel(
            letterName: "Small n",
            imagePath: '',
            strokes: [
              [const Offset(0.35, 0.40), const Offset(0.35, 0.80)],
              [
                const Offset(0.35, 0.56),
                const Offset(0.39, 0.46),
                const Offset(0.50, 0.41),
                const Offset(0.61, 0.46),
                const Offset(0.65, 0.56),
                const Offset(0.65, 0.80),
              ],
            ],
          ),
        ];
        break;
      case 'O':
        _levels = [
          TraceLevel(
            letterName: "Big O",
            imagePath: '',
            strokes: [
              [
                const Offset(0.50, 0.20),
                const Offset(0.40, 0.24),
                const Offset(0.33, 0.35),
                const Offset(0.30, 0.50),
                const Offset(0.33, 0.65),
                const Offset(0.40, 0.76),
                const Offset(0.50, 0.80),
                const Offset(0.60, 0.76),
                const Offset(0.67, 0.65),
                const Offset(0.70, 0.50),
                const Offset(0.67, 0.35),
                const Offset(0.60, 0.24),
                const Offset(0.50, 0.20),
                const Offset(0.40, 0.24),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small o",
            imagePath: '',
            strokes: [
              [
                const Offset(0.50, 0.40),
                const Offset(0.425, 0.43),
                const Offset(0.37, 0.50),
                const Offset(0.35, 0.60),
                const Offset(0.37, 0.70),
                const Offset(0.425, 0.77),
                const Offset(0.50, 0.80),
                const Offset(0.575, 0.77),
                const Offset(0.63, 0.70),
                const Offset(0.65, 0.60),
                const Offset(0.63, 0.50),
                const Offset(0.575, 0.43),
                const Offset(0.50, 0.40),
                const Offset(0.425, 0.43),
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
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)],
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.7, 0.35),
                const Offset(0.6, 0.5),
                const Offset(0.3, 0.5),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small p",
            imagePath: '',
            strokes: [
              [const Offset(0.34, 0.28), const Offset(0.34, 0.83)],
              [
                const Offset(0.34, 0.38),
                const Offset(0.42, 0.30),
                const Offset(0.54, 0.28),
                const Offset(0.64, 0.36),
                const Offset(0.67, 0.48),
                const Offset(0.64, 0.60),
                const Offset(0.54, 0.68),
                const Offset(0.42, 0.66),
                const Offset(0.34, 0.58),
              ],
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
                const Offset(0.50, 0.20),
                const Offset(0.40, 0.24),
                const Offset(0.33, 0.35),
                const Offset(0.30, 0.50),
                const Offset(0.33, 0.65),
                const Offset(0.40, 0.76),
                const Offset(0.50, 0.80),
                const Offset(0.60, 0.76),
                const Offset(0.67, 0.65),
                const Offset(0.70, 0.50),
                const Offset(0.67, 0.35),
                const Offset(0.60, 0.24),
                const Offset(0.50, 0.20),
                const Offset(0.40, 0.24),
              ], // Circle
              [const Offset(0.56, 0.66), const Offset(0.76, 0.86)],
            ],
          ),
          TraceLevel(
            letterName: "Small q",
            imagePath: '',
            strokes: [
              [
                const Offset(0.66, 0.36),
                const Offset(0.56, 0.29),
                const Offset(0.44, 0.30),
                const Offset(0.35, 0.40),
                const Offset(0.34, 0.54),
                const Offset(0.42, 0.65),
                const Offset(0.54, 0.68),
                const Offset(0.66, 0.62),
              ],
              [const Offset(0.66, 0.28), const Offset(0.66, 0.83)],
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
                const Offset(0.68, 0.28),
                const Offset(0.62, 0.22),
                const Offset(0.53, 0.20),
                const Offset(0.44, 0.21),
                const Offset(0.36, 0.26),
                const Offset(0.33, 0.34),
                const Offset(0.37, 0.42),
                const Offset(0.46, 0.48),
                const Offset(0.55, 0.52),
                const Offset(0.64, 0.57),
                const Offset(0.68, 0.65),
                const Offset(0.64, 0.73),
                const Offset(0.56, 0.78),
                const Offset(0.46, 0.80),
                const Offset(0.38, 0.77),
                const Offset(0.32, 0.71),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small s",
            imagePath: '',
            strokes: [
              [
                const Offset(0.635, 0.453),
                const Offset(0.59, 0.413),
                const Offset(0.52, 0.40),
                const Offset(0.455, 0.407),
                const Offset(0.395, 0.44),
                const Offset(0.37, 0.493),
                const Offset(0.40, 0.547),
                const Offset(0.47, 0.587),
                const Offset(0.54, 0.613),
                const Offset(0.605, 0.647),
                const Offset(0.635, 0.70),
                const Offset(0.605, 0.753),
                const Offset(0.545, 0.787),
                const Offset(0.47, 0.80),
                const Offset(0.41, 0.78),
                const Offset(0.365, 0.74),
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
              [const Offset(0.2, 0.2), const Offset(0.8, 0.2)],
              [const Offset(0.5, 0.2), const Offset(0.5, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small t",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.2), const Offset(0.5, 0.8)],
              [const Offset(0.3, 0.45), const Offset(0.7, 0.45)],
            ],
          ),
        ];
        break;

      case 'U':
        _levels = [
          TraceLevel(
            letterName: "Capital U",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.2),
                const Offset(0.3, 0.6),
                const Offset(0.35, 0.72),
                const Offset(0.5, 0.78),
                const Offset(0.65, 0.72),
                const Offset(0.7, 0.6),
                const Offset(0.7, 0.2),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small u",
            imagePath: '',
            strokes: [
              [
                const Offset(0.35, 0.4),
                const Offset(0.35, 0.65),
                const Offset(0.4, 0.73),
                const Offset(0.5, 0.76),
                const Offset(0.6, 0.73),
                const Offset(0.65, 0.65),
                const Offset(0.65, 0.4),
              ],
              [const Offset(0.65, 0.4), const Offset(0.65, 0.76)],
            ],
          ),
        ];
        break;
      case 'V':
        _levels = [
          TraceLevel(
            letterName: "Capital V",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.2), const Offset(0.5, 0.78)],
              [const Offset(0.5, 0.78), const Offset(0.75, 0.2)],
            ],
          ),
          TraceLevel(
            letterName: "Small v",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.4), const Offset(0.5, 0.76)],
              [const Offset(0.5, 0.76), const Offset(0.7, 0.4)],
            ],
          ),
        ];
        break;
      case 'W':
        _levels = [
          TraceLevel(
            letterName: "Capital W",
            imagePath: '',
            strokes: [
              [const Offset(0.15, 0.2), const Offset(0.32, 0.78)],
              [const Offset(0.32, 0.78), const Offset(0.5, 0.35)],
              [const Offset(0.5, 0.35), const Offset(0.68, 0.78)],
              [const Offset(0.68, 0.78), const Offset(0.85, 0.2)],
            ],
          ),
          TraceLevel(
            letterName: "Small w",
            imagePath: '',
            strokes: [
              [const Offset(0.15, 0.4), const Offset(0.32, 0.76)],
              [const Offset(0.32, 0.76), const Offset(0.5, 0.5)],
              [const Offset(0.5, 0.5), const Offset(0.68, 0.76)],
              [const Offset(0.68, 0.76), const Offset(0.85, 0.4)],
            ],
          ),
        ];
        break;

      case 'X':
        _levels = [
          TraceLevel(
            letterName: "Big X",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.2), const Offset(0.75, 0.8)],
              [const Offset(0.75, 0.2), const Offset(0.25, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small x",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.45), const Offset(0.7, 0.8)],
              [const Offset(0.7, 0.45), const Offset(0.3, 0.8)],
            ],
          ),
        ];
        break;

      case 'Y':
        _levels = [
          TraceLevel(
            letterName: "Big Y",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.2), const Offset(0.5, 0.45)],
              [const Offset(0.75, 0.2), const Offset(0.5, 0.45)],
              [const Offset(0.5, 0.45), const Offset(0.5, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small y",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.4), const Offset(0.5, 0.7)],
              [const Offset(0.7, 0.4), const Offset(0.4, 0.9)],
            ],
          ),
        ];
        break;

      case 'Z':
        _levels = [
          TraceLevel(
            letterName: "Big Z",
            imagePath: '',
            strokes: [
              [const Offset(0.2, 0.2), const Offset(0.8, 0.2)],
              [const Offset(0.8, 0.2), const Offset(0.2, 0.8)],
              [const Offset(0.2, 0.8), const Offset(0.8, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small z",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.45), const Offset(0.7, 0.45)],
              [const Offset(0.7, 0.45), const Offset(0.3, 0.8)],
              [const Offset(0.3, 0.8), const Offset(0.7, 0.8)],
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

  void _generateDensePaths(Size size) {
    if (size.isEmpty) return;

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
        final p0 = i == 0
            ? pts[i]
            : pts[i - 1]; // ADD: neighbor points for the curve
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];

        final distance = (p2 - p1).distance;
        final steps = (distance / 5.0).ceil().clamp(1, 999);

        for (int j = 0; j <= steps; j++) {
          final t = j / steps;
          densePoints.add(
            _catmullRom(p0, p1, p2, p3, t),
          ); // CHANGED from straight lerp
        }
      }
      newDenseStrokes.add(densePoints);
    }

    setState(() {
      _denseStrokes = newDenseStrokes;
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (!_audioFinished) return;
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    final stroke = _denseStrokes[_currentStrokeIndex];
    if (!_isDotStroke(stroke)) return;

    if ((details.localPosition - stroke.first).distance < 60.0) {
      setState(() => _currentPointIndex = stroke.length);
      _moveToNextStroke();
      _awaitingLift = false;
    }
  }

  Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    final x =
        0.5 *
        ((2 * p1.dx) +
            (p2.dx - p0.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (3 * p1.dx - p0.dx - 3 * p2.dx + p3.dx) * t3);
    final y =
        0.5 *
        ((2 * p1.dy) +
            (p2.dy - p0.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (3 * p1.dy - p0.dy - 3 * p2.dy + p3.dy) * t3);
    return Offset(x, y);
  }

  void _onPanStart(DragStartDetails details) {
    _touchValid = false;
    if (!_audioFinished) return;
    if (_awaitingLift) return;
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    final stroke = _denseStrokes[_currentStrokeIndex];
    if (_isDotStroke(stroke)) return;
    if (_currentPointIndex >= stroke.length) return;

    final d = (details.localPosition - stroke[_currentPointIndex]).distance;
    _touchValid = d < 60.0;
  }

  void _onPanEnd(DragEndDetails details) {
    _awaitingLift = false;
    _touchValid = false;
  }

  void _onPanCancel() {
    _awaitingLift = false;
    _touchValid = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_awaitingLift || !_touchValid) return;
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    final dragPos = details.localPosition;
    final currentStroke = _denseStrokes[_currentStrokeIndex];
    if (_currentPointIndex >= currentStroke.length) return;

    const double reach = 40.0;
    const int lookAhead = 20;

    int best = -1;
    double bestDist = reach;
    final end = min(currentStroke.length, _currentPointIndex + lookAhead);

    for (int i = _currentPointIndex; i < end; i++) {
      final d = (dragPos - currentStroke[i]).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }

    if (best < 0) return;

    setState(() => _currentPointIndex = best + 1);

    if (_currentPointIndex >= currentStroke.length) {
      _moveToNextStroke();
    }
  }

  void _moveToNextStroke() {
    _tapTracker.recordCorrectTap();
    _awaitingLift = true;
    _touchValid = false;
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

    if (!mounted) return;

    if (!isLastSubLevel) {
      setState(() {
        _resetBoard();
        _currentLevelIndex++;
      });
      _generateDensePaths(_lastCanvasSize);
      return;
    }

    // --- 1. STOP CAMERA AND SAVE DATA ---
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'letter_trace_${widget.letter.toLowerCase()}',
      activityName: "Alphabet Trace (${widget.letter.toUpperCase()})",
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps, // Represents strokes completed
      mistakes: 0, // Tracing doesn't record discrete mistakes
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });
    // --- 2. SMART MINI-GAME ROUTER ---
    String letter = widget.letter.toUpperCase();

    final miniGames = [
      AlphabetPopScreen(letter: letter),
      AlphabetPuzzleScreen(letter: letter),
      AlphabetHuntScreen(letter: letter),
      AlphabetFallScreen(letter: letter),
      AlphabetFindScreen(letter: letter),
    ];

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => miniGames[_nextMiniGame()],
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_forest.png',
              fit: BoxFit.cover,
            ),
          ),

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
                            left: 25,
                            child: ForestXButton(),
                          ),
                          Positioned(
                            top: 25,
                            right: 20,
                            child: ForestLevelBadge(
                              level:
                                  ForestProgressService.levelNumberForLetter(
                                    widget.letter,
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
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final size = constraints.biggest;
                                  if (size != _lastCanvasSize) {
                                    _lastCanvasSize = size;
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) _generateDensePaths(size);
                                    });
                                  }
                                  return Stack(
                                    children: [
                                      GestureDetector(
                                        onTapDown: _onTapDown,
                                        onPanStart: _onPanStart,
                                        onPanUpdate: _onPanUpdate,
                                        onPanEnd: _onPanEnd,
                                        onPanCancel: _onPanCancel,
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
                                  );
                                },
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

          // 2. The Lighting Prompt Card (Valid here because it's inside the outer Stack's children list)
          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate(); // don't leave the tutorial audio waiting
              },
            ),
        ],
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
