import 'dart:math';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/catching_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'lagoon_game_ui.dart';

// 1. Added 'goodJob' phase for the final victory screen!
enum GamePhase {
  intro,
  listening,
  choosing,
  answered,
  completed,
  bodyParts,
  goodJob,
}

class ListeningGame extends StatefulWidget {
  final int level;

  const ListeningGame({super.key, required this.level});

  @override
  State<ListeningGame> createState() => _ListeningGameState();
}

class _ListeningGameState extends State<ListeningGame> {
  late final AudioPlayer _audioPlayer;
  GamePhase _currentPhase = GamePhase.intro;

  // Tracks which animal sound the player needs to listen for right now![cite: 7]
  String _targetAnimal = 'chicken';

  // Master list of all available animals in the game[cite: 7]
  final List<Map<String, String>> _allAnimals = [
    {'id': 'chicken', 'image': 'assets/images/objects/lagoon/chicken.png'},
    {'id': 'frog', 'image': 'assets/images/objects/lagoon/frog.png'},
    {'id': 'snake', 'image': 'assets/images/objects/lagoon/snake.png'},
    {'id': 'pig', 'image': 'assets/images/objects/lagoon/pig.png'},
    {'id': 'cow', 'image': 'assets/images/objects/lagoon/cow.png'},
    {
      'id': 'penguin',
      'image': 'assets/images/characters/doma_the_penguin2.png',
    },
    {'id': 'dog', 'image': 'assets/images/characters/tofi_smiling.png'},
  ];

  // Holds the 3 currently displayed choices for the active round[cite: 7]
  List<Map<String, String>> _currentChoices = [];

  // Holds the 3 body part cards (Ear, Hand, Nose) for the final UI[cite: 7]
  final List<Map<String, String>> _bodyParts = [
    {'id': 'ear', 'image': 'assets/images/objects/lagoon/ear.png'},
    {'id': 'hand', 'image': 'assets/images/objects/lagoon/pointing_hand.png'},
    {'id': 'nose', 'image': 'assets/images/objects/lagoon/nose.png'},
  ];

  @override
  void initState() {
    super.initState();
    // 1. FORCE LANDSCAPE ORIENTATION[cite: 7]
    OrientationService.setLandscape();

    // 2. ENABLE TRUE IMMERSIVE FULLSCREEN (Hides system status & navigation bars)[cite: 7]
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _audioPlayer = AudioPlayer();
    _playIntroAudio();
  }

  /// Helper: Picks the target animal + 2 random wrong animals, then shuffles them![cite: 7]
  void _generateChoices() {
    final targetObj = _allAnimals.firstWhere((a) => a['id'] == _targetAnimal);
    final wrongChoices = _allAnimals
        .where((a) => a['id'] != _targetAnimal)
        .toList();
    wrongChoices.shuffle(Random());

    final selected = [targetObj, wrongChoices[0], wrongChoices[1]];
    selected.shuffle(Random());

    setState(() {
      _currentChoices = selected;
    });
  }

  /// Plays the intro voiceover automatically when the screen loads.[cite: 7]
  Future<void> _playIntroAudio() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/listening_intro.wav'),
      );

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          _startListeningPhase();
        }
      });
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
    }
  }

  /// Shows speaker.gif, plays target animal sound, then asks the follow-up question[cite: 7]
  Future<void> _startListeningPhase() async {
    _generateChoices();

    setState(() {
      _currentPhase = GamePhase.listening;
    });

    try {
      String audioPath;
      if (_targetAnimal == 'chicken') {
        audioPath = 'audio/discovery_lagoon/listening_chicken.wav';
      } else if (_targetAnimal == 'frog') {
        audioPath = 'audio/discovery_lagoon/listening_frog.wav';
      } else if (_targetAnimal == 'snake') {
        audioPath = 'audio/discovery_lagoon/listening_snake.wav';
      } else if (_targetAnimal == 'pig') {
        audioPath = 'audio/discovery_lagoon/listening_pig.wav';
      } else {
        audioPath = 'audio/discovery_lagoon/listening_cow.wav';
      }

      await _audioPlayer.play(AssetSource(audioPath));

      _audioPlayer.onPlayerComplete.first.then((_) async {
        if (mounted) {
          try {
            await _audioPlayer.play(
              AssetSource('audio/discovery_lagoon/listening_whatanimal.wav'),
            );

            _audioPlayer.onPlayerComplete.first.then((_) {
              if (mounted) {
                setState(() {
                  _currentPhase = GamePhase.choosing;
                });
              }
            });
          } catch (e) {
            debugPrint("Error playing whatanimal audio: $e");
          }
        }
      });
    } catch (e) {
      debugPrint("Error playing target animal audio: $e");
    }
  }

  /// Helper method to play Kiki's feedback audio[cite: 7]
  Future<void> _playKikiAudio(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing audio ($assetPath): $e");
    }
  }

  /// Handles when the user taps on an animal[cite: 7]
  void _onAnimalTapped(String animalName) {
    if (_currentPhase != GamePhase.choosing) return;

    if (animalName == _targetAnimal) {
      setState(() {
        _currentPhase = GamePhase.answered;
      });

      _playKikiAudio('audio/sound_effects/shine.wav');
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          _playKikiAudio('audio/discovery_lagoon/listening_rc.wav');

          _audioPlayer.onPlayerComplete.first.then((_) {
            if (mounted) {
              if (_targetAnimal == 'chicken') {
                setState(() => _targetAnimal = 'frog');
                _startListeningPhase();
              } else if (_targetAnimal == 'frog') {
                setState(() => _targetAnimal = 'snake');
                _startListeningPhase();
              } else if (_targetAnimal == 'snake') {
                setState(() => _targetAnimal = 'pig');
                _startListeningPhase();
              } else if (_targetAnimal == 'pig') {
                setState(() => _targetAnimal = 'cow');
                _startListeningPhase();
              } else {
                // All 5 animal rounds complete! Show Kiki and play ending clip[cite: 7]
                setState(() {
                  _currentPhase = GamePhase.completed;
                });
                _playKikiAudio('audio/discovery_lagoon/listening_ending1.wav');

                // When ending clip finishes, transition to the Body Parts UI![cite: 7]
                _audioPlayer.onPlayerComplete.first.then((_) {
                  if (mounted) {
                    setState(() {
                      _currentPhase = GamePhase.bodyParts;
                    });
                    _playKikiAudio(
                      'audio/discovery_lagoon/listening_whatpart.wav',
                    );
                  }
                });
              }
            }
          });
        }
      });
    } else {
      _playKikiAudio('audio/discovery_lagoon/kiki_tryagain.wav');
    }
  }

  /// Handles taps during the final Body Parts mini-game[cite: 7]
  void _onBodyPartTapped(String partId) {
    if (_currentPhase != GamePhase.bodyParts) return;

    if (partId == 'ear') {
      _playKikiAudio('audio/sound_effects/shine.wav');
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          _playKikiAudio('audio/discovery_lagoon/listening_whatpart_rc.wav');

          // 2. WHEN THIS FINISHES, SHOW THE GOOD JOB OVERLAY![cite: 7]
          _audioPlayer.onPlayerComplete.first.then((_) {
            if (mounted) {
              setState(() {
                _currentPhase = GamePhase.goodJob;
              });
            }
          });
        }
      });
    } else {
      _playKikiAudio('audio/discovery_lagoon/kiki_tryagain.wav');
    }
  }

  /// Helper to restart the whole game from the beginning!
  void _restartGame() {
    setState(() {
      _targetAnimal = 'chicken';
      _currentPhase = GamePhase.intro;
    });
    _playIntroAudio();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sh = MediaQuery.of(context).size.height;

    final double catHeight = sh * 1.0;
    final double catBottom = sh * -0.25;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A. BACKGROUND LAYER[cite: 7]
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_lagoon.png',
            fit: BoxFit.cover,
          ),

          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

          // B. FOREGROUND CHARACTER LAYER (Standard Kiki during intro & completed)[cite: 7]
          if (_currentPhase == GamePhase.intro ||
              _currentPhase == GamePhase.completed)
            Positioned(
              bottom: catBottom,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/characters/kiki_the_cat.png',
                  height: catHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // C. SPEAKER GIF LAYER[cite: 7]
          if (_currentPhase == GamePhase.listening)
            Center(
              child: Image.asset(
                'assets/images/objects/lagoon/speaker.gif',
                height: sh * 0.60,
                fit: BoxFit.contain,
              ),
            ),

          // D. ANIMAL CHOICES LAYER[cite: 7]
          if (_currentPhase == GamePhase.choosing ||
              _currentPhase == GamePhase.answered)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _currentChoices.map((animal) {
                    return _buildAnimalChoice(
                      animal['image']!,
                      animal['id']!,
                      sh,
                    );
                  }).toList(),
                ),
              ),
            ),

          // E. BODY PARTS CHALLENGE LAYER[cite: 7]
          if (_currentPhase == GamePhase.bodyParts) ...[
            Positioned(
              bottom: sh * -0.35, // Pushed down so half body shows!
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/characters/cat_holding_fishbone.png',
                  height: sh * 0.95,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: sh * 0.05,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _bodyParts.map((part) {
                      return _buildBodyPartCard(
                        part['image']!,
                        part['id']!,
                        sh,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],

          // F. GOOD JOB OVERLAY LAYER (Appears after winning!)
          if (_currentPhase == GamePhase.goodJob)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/cat_holding_fishbone.png',
              closeButtonColor: LagoonColorTheme.wasteland,
              characterSizeFactor: 0.9,
              onNext: () async {
                // Mark Level 3 as complete to unlock Level 4
                await LagoonProgressService.instance.markLevelComplete(3);
                if (context.mounted) {
                  // Jump to Level 4 (Catching)
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => CatchingGameScreen(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: _restartGame,
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimalChoice(
    String imagePath,
    String animalId,
    double screenHeight,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onAnimalTapped(animalId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Image.asset(
            imagePath,
            height: screenHeight * 0.55,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyPartCard(
    String imagePath,
    String partId,
    double screenHeight,
  ) {
    final double cardSize = screenHeight * 0.35;

    return GestureDetector(
      onTap: () => _onBodyPartTapped(partId),
      child: Container(
        width: cardSize,
        height: cardSize,
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}