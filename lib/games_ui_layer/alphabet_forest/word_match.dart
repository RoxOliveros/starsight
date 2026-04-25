import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

//@Ron fix the size of the speakers
//@Ron fix the volume of the audio (currently too quiet)
//@Ron Put a functions

abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8);
  static const Color deepNavyBlue = Color(0xFF5E463E);
  static const Color orange = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class WordMatchScreen extends StatefulWidget {
  WordMatchScreen({super.key});

  @override
  State<WordMatchScreen> createState() => _WordMatchScreenState();
}

class _WordMatchScreenState extends State<WordMatchScreen> {
  // created one audio player to handle all the sounds
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Offset> _currentLine = [];
  List<List<Offset>> _completedLines = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Clean up the audio player when leaving the screen
    _audioPlayer.dispose();

    // Unlock orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // The function to play the custom voiceovers
  void _playSound(String fileName) async {
    await _audioPlayer.setVolume(1.0);
    await _audioPlayer.play(AssetSource('audio/$fileName'));
  }

  // --- THE SUBMIT FUNCTION ---
  void _checkAnswers() {
    // If they haven't drawn anything, don't do anything
    if (_completedLines.isEmpty) {
      return;
    }

    // Show a Success Popup
    showDialog(
      context: context,
      barrierDismissible: false, // Forces them to click the button to close
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: ColorTheme.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Center(
            child: Text(
              'Great Job!',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: ColorTheme.deepNavyBlue,
              ),
            ),
          ),
          content: const Text(
            'You connected the words!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 24,
              color: ColorTheme.deepNavyBlue,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the popup
                setState(() {
                  _completedLines.clear(); // Erase the orange lines
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorTheme.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Play Again',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 0),

            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: ColorTheme.deepNavyBlue,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Match the pictures with words',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.deepNavyBlue,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // --- THE GAME BOARD ---
            Expanded(
              child: GestureDetector(
                // 1. When the child touches the screen, start a new line
                onPanStart: (details) {
                  setState(() {
                    _currentLine = [details.localPosition];
                  });
                },
                // 2. As they drag their finger, add points to the line
                onPanUpdate: (details) {
                  setState(() {
                    _currentLine.add(details.localPosition);
                  });
                },
                // 3. When they let go, save the line
                onPanEnd: (details) {
                  setState(() {
                    if (_currentLine.isNotEmpty) {
                      _completedLines.add(List.from(_currentLine));
                      _currentLine = []; // Clear the active line
                    }
                  });
                },
                child: Stack(
                  children: [
                    // LAYER 1: Your original layout (Images and Words)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // LEFT COLUMN (Images)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildImageItem('assets/images/dog.png'),
                              _buildImageItem('assets/images/penguin.png'),
                              _buildImageItem('assets/images/bunny.png'),
                            ],
                          ),
                          // RIGHT COLUMN (Words & Speakers)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWordItem('Penguin', 'penguin.mp3'),
                              _buildWordItem('Bunny', 'bunny.mp3'),
                              _buildWordItem('Dog', 'dog.mp3'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // LAYER 2: The Invisible Glass that draws the lines
                    CustomPaint(
                      painter: MatchPainter(
                        currentLine: _currentLine,
                        completedLines: _completedLines,
                      ),
                      size: Size.infinite,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _checkAnswers,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorTheme.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 8,
                ),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDER: Left Side (Image + Dot) ---
  Widget _buildImageItem(String imagePath) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(imagePath, height: 65, width: 65, fit: BoxFit.contain),
        const SizedBox(width: 24),
        _buildConnectionDot(),
      ],
    );
  }

  // --- WIDGET BUILDER: Right Side (Dot + Word + Speaker) ---
  Widget _buildWordItem(String word, String audioFileName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildConnectionDot(),
        const SizedBox(width: 24),

        // The Text Word
        SizedBox(
          width: 140,
          child: Text(
            word,
            style: const TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ColorTheme.deepNavyBlue,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // The Animated Speaker Button
        GestureDetector(
          onTap: () => _playSound(audioFileName),
          child: Image.asset(
            'assets/gifs/speaker.gif',
            height: 65,
            width: 65,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  // --- WIDGET BUILDER: The Black Connection Dots ---
  Widget _buildConnectionDot() {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
    );
  }
}

class MatchPainter extends CustomPainter {
  final List<Offset> currentLine;
  final List<List<Offset>> completedLines;

  MatchPainter({required this.currentLine, required this.completedLines});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ColorTheme.orange
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 1. Draw all the finished lines
    for (var line in completedLines) {
      for (int i = 0; i < line.length - 1; i++) {
        canvas.drawLine(line[i], line[i + 1], paint);
      }
    }

    // 2. Draw the line the child is currently dragging
    for (int i = 0; i < currentLine.length - 1; i++) {
      canvas.drawLine(currentLine[i], currentLine[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant MatchPainter oldDelegate) => true;
}
