import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../ui_layer/lumi_town/lumi_theme.dart';

class Lumi2ValuesWakingup extends StatefulWidget {
  const Lumi2ValuesWakingup({super.key});

  @override
  State<Lumi2ValuesWakingup> createState() => _Lumi2ValuesWakingupState();
}

class _Lumi2ValuesWakingupState extends State<Lumi2ValuesWakingup> {
  bool _showNext = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playAlarm();
    Future.delayed(const Duration(seconds: 10), () async {
      if (mounted) {
        await _audioPlayer.stop();
        setState(() => _showNext = true);
        await _playNext();
      }
    });
  }

  Future<void> _playAudio(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final Directory cacheDir = await getTemporaryDirectory();
      final String fileName = assetPath.split('/').last;
      final File tempFile = File('${cacheDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes, flush: true);
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
    } catch (e) {
      debugPrint('[Audio] Error: $e');
    }
  }

  Future<void> _playAlarm() =>
      _playAudio('assets/audio/values1/alarmclock.wav');

  Future<void> _playNext() => _playAudio('assets/audio/values1/salamat.mp3');

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        child: _showNext ? _buildNext() : _buildAwake(),
      ),
    );
  }

  Widget _buildAwake() {
    return SizedBox.expand(
      key: const ValueKey('awake'),
        child: Stack(fit: StackFit.expand,
          children: [
            Image.asset('assets/gifs/awake.gif', fit: BoxFit.cover),

            //X button
            Positioned(top: 25, left: 25, child: LumiXButton()),
          ],)
    );
  }

  Widget _buildNext() {
    return SizedBox.expand(
      key: const ValueKey('next'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/wakeup_BG.png', fit: BoxFit.cover),
          Positioned(
            left: 160,
            bottom: -80,
            child: Image.asset(
              'assets/images/bear.png',
              width: 300,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 480,
            bottom: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 110),
                  painter: _SpeechBubblePainter(),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        '✨ Salamat! ✨',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: LumiAppTextStyles.fredoka,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5A3E00),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Magandang umaga!',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: LumiAppTextStyles.fredoka,
                          color: Color(0xFF8B6200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          //X button
          Positioned(top: 25, left: 25, child: LumiXButton()),
        ],
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bubbleRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.78);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bubbleRect.translate(0, 4),
        const Radius.circular(24),
      ),
      shadowPaint,
    );

    // Fill with warm white
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFFFFBF0), const Color(0xFFFFF3CC)],
      ).createShader(bubbleRect);
    final rrect = RRect.fromRectAndRadius(bubbleRect, const Radius.circular(24));
    canvas.drawRRect(rrect, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = const Color(0xFFE8C84A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rrect, borderPaint);

    // Tail pointing left toward bear
    final tail = Path()
      ..moveTo(24, size.height * 0.78)
      ..lineTo(4, size.height)
      ..lineTo(54, size.height * 0.78)
      ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFFFFF3CC));
    canvas.drawPath(tail, borderPaint);
  }

  @override
  bool shouldRepaint(_SpeechBubblePainter oldDelegate) => false;
}