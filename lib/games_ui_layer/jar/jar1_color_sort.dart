import 'dart:math';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/jar/jar_buttons.dart';
import '../../ui_layer/jar/jar_theme.dart';

class JarColorSortScreen extends StatefulWidget {
  const JarColorSortScreen({super.key});

  @override
  State<JarColorSortScreen> createState() => _JarColorSortScreenState();
}

class _JarColorSortScreenState extends State<JarColorSortScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────

  static const int _totalRounds = 5;
  static const int _ballsPerColor = 3;

  static const _allPairs = [
    _JarPair(
      label: 'Red',
      jarColor: Color(0xFFE05A5A),
      ballColor: Color(0xFFF28B8B),
    ),
    _JarPair(
      label: 'Blue',
      jarColor: Color(0xFF4C7FBE),
      ballColor: Color(0xFF82B1E8),
    ),
    _JarPair(
      label: 'Green',
      jarColor: Color(0xFF5AAE6A),
      ballColor: Color(0xFF90D49A),
    ),
    _JarPair(
      label: 'Yellow',
      jarColor: Color(0xFFF9AB19),
      ballColor: Color(0xFFFDCE57),
    ),
    _JarPair(
      label: 'Purple',
      jarColor: Color(0xFF9B6DC5),
      ballColor: Color(0xFFC4A0E8),
    ),
    _JarPair(
      label: 'Orange',
      jarColor: Color(0xFFF07030),
      ballColor: Color(0xFFF9A468),
    ),
  ];

  // ── Round state ────────────────────────────────────────────────────────────

  int _round = 1;

  late _JarPair _jarA;
  late _JarPair _jarB;

  late List<_Ball> _poolBalls;
  late List<_Ball> _jarABalls;
  late List<_Ball> _jarBBalls;

  bool _wrongFlashA = false;
  bool _wrongFlashB = false;
  bool _roundComplete = false;

  // ── Animations ─────────────────────────────────────────────────────────────

  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _celebCtrl;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startRound();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _enterCtrl.dispose();
    _celebCtrl.dispose();
    super.dispose();
  }

  // ── Round logic ────────────────────────────────────────────────────────────

  void _startRound() {
    final shuffled = List<_JarPair>.from(_allPairs)..shuffle(Random());
    _jarA = shuffled[0];
    _jarB = shuffled[1];

    final balls = [
      ...List.generate(_ballsPerColor, (_) => _Ball(jarIndex: 0, pair: _jarA)),
      ...List.generate(_ballsPerColor, (_) => _Ball(jarIndex: 1, pair: _jarB)),
    ]..shuffle(Random());
    _poolBalls = balls;

    _jarABalls = [];
    _jarBBalls = [];
    _wrongFlashA = false;
    _wrongFlashB = false;
    _roundComplete = false;
    _celebCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  Future<void> _onDroppedOnJar(int jarIndex, _Ball ball) async {
    if (_roundComplete) return;

    final correctJar = ball.jarIndex == jarIndex;

    if (correctJar) {
      setState(() {
        _poolBalls.remove(ball);
        if (jarIndex == 0) {
          _jarABalls.add(ball);
        } else {
          _jarBBalls.add(ball);
        }
      });

      if (_jarABalls.length == _ballsPerColor &&
          _jarBBalls.length == _ballsPerColor) {
        setState(() => _roundComplete = true);
        _celebCtrl.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 1200));

        if (_round >= _totalRounds) {
          _showEndDialog();
        } else {
          await _enterCtrl.reverse();
          setState(() {
            _round++;
            _startRound();
          });
        }
      }
    } else {
      setState(() {
        if (jarIndex == 0) {
          _wrongFlashA = true;
        } else {
          _wrongFlashB = true;
        }
      });
      await Future.delayed(const Duration(milliseconds: 700));
      setState(() {
        _wrongFlashA = false;
        _wrongFlashB = false;
      });
    }
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: JarColorTheme.vandecane,
        title: const Text(
          '🌟 Amazing Sorter!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: JarColorTheme.verydarkdesaturatedblue,
          ),
        ),
        content: const Text(
          'You sorted all the jars perfectly!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 20,
            color: JarColorTheme.darkdesaturatedblue,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _round = 1;
                _startRound();
              });
            },
            child: const Text(
              'Play Again',
              style: TextStyle(
                fontFamily: JarAppTextStyles.fredoka,
                fontSize: 20,
                color: JarColorTheme.sunnyhue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarColorTheme.lightgrayishyellow,
      body: SafeArea(
        child: FadeTransition(
          opacity: _enterAnim,
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHeader(),
              const SizedBox(height: 4),
              _buildPrompt(),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 4, child: _buildBallPool()),
                    Expanded(flex: 5, child: _buildJarsRow()),
                  ],
                ),
              ),
              _buildProgressDots(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: JarBackButton()),
          const Text(
            'Jar Color Sort',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: JarColorTheme.verydarkdesaturatedblue,
            ),
          ),
        ],
      ),
    );
  }

  // ── Prompt ─────────────────────────────────────────────────────────────────

  Widget _buildPrompt() {
    return Text(
      _roundComplete
          ? '🎉 Great job! All sorted!'
          : 'Drag each ball into the matching jar!',
      style: TextStyle(
        fontFamily: JarAppTextStyles.fredoka,
        fontSize: 20,
        color: _roundComplete
            ? JarColorTheme.sunnyhue
            : JarColorTheme.verydarkdesaturatedblue,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── Ball pool ──────────────────────────────────────────────────────────────

  Widget _buildBallPool() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: JarColorTheme.vandecane,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.55),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: JarColorTheme.goldenyellow.withValues(alpha: 0.20),
            blurRadius: 0,
            spreadRadius: 3,
            offset: Offset.zero,
          ),
        ],
      ),
      child: _poolBalls.isEmpty
          ? Center(
        child: Text(
          '✨ All done!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 22,
            color: JarColorTheme.sunnyhue,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: List.generate(_poolBalls.length, (i) {
          return _buildDraggableBall(_poolBalls[i], i);
        }),
      ),
    );
  }

  Widget _buildDraggableBall(_Ball ball, int index) {
    Widget starWidget(double size) => Image.asset(
      'assets/images/star_bnw.png',
      width: size,
      height: size,
      color: ball.pair.ballColor,
      colorBlendMode: BlendMode.modulate,
    );

    return Draggable<_Ball>(
      data: ball,
      feedback: Material(
        color: Colors.transparent,
        child: starWidget(62),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: starWidget(54)),
      child: starWidget(54),
    );
  }

  // ── Jars row ───────────────────────────────────────────────────────────────

  Widget _buildJarsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildJarTarget(0, _jarA, _jarABalls, _wrongFlashA),
        _buildJarTarget(1, _jarB, _jarBBalls, _wrongFlashB),
      ],
    );
  }

  Widget _buildJarTarget(
      int jarIndex,
      _JarPair pair,
      List<_Ball> contents,
      bool wrongFlash,
      ) {
    final isFull = contents.length == _ballsPerColor;

    return DragTarget<_Ball>(
      onWillAcceptWithDetails: (details) => !isFull,
      onAcceptWithDetails: (details) => _onDroppedOnJar(jarIndex, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Jar image
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isHovering ? 115 : 105,
                  height: isHovering ? 130 : 120,
                  child: Image.asset(
                    'assets/images/jar_bnw.png',
                    fit: BoxFit.fill,
                    color: wrongFlash ? JarColorTheme.goldenyellow.withValues(alpha: 0.6) : pair.jarColor.withValues(alpha: 0.85),
                    colorBlendMode: BlendMode.modulate,
                  ),
                ),

                // Stars inside jar
                if (contents.isNotEmpty)
                  Positioned(
                    bottom: 20,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 0,
                      runSpacing: 2,
                      children: contents.map((b) => Image.asset(
                        'assets/images/star_bnw.png',
                        width: 26,
                        height: 26,
                        color: b.pair.ballColor,
                        colorBlendMode: BlendMode.modulate,
                      )).toList(),
                    ),
                  ),

                // Hover arrow
                if (isHovering && !isFull)
                  Positioned(
                    bottom: 20,
                    child: Icon(Icons.arrow_downward_rounded, color: pair.jarColor, size: 28),
                  ),

                // Wrong flash text
                if (wrongFlash)
                  Positioned(
                    bottom: 8,
                    child: Text('Oops! 💛', style: TextStyle(
                      fontFamily: JarAppTextStyles.fredoka,
                      fontSize: 13,
                      color: JarColorTheme.darkbrown,
                      fontWeight: FontWeight.bold,
                    )),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? JarColorTheme.darkdesaturatedblue
                : current
                ? JarColorTheme.sunnyhue
                : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _JarPair {
  final String label;
  final Color jarColor;
  final Color ballColor;

  const _JarPair({
    required this.label,
    required this.jarColor,
    required this.ballColor,
  });
}

class _Ball {
  final int jarIndex;
  final _JarPair pair;

  _Ball({required this.jarIndex, required this.pair});
}