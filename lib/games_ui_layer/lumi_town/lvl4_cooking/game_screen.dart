import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../ui_layer/lumi_town/town_level.dart';
import '../../goodjob_prompt.dart';
import 'audio_manager.dart';
import 'bear_speech_bubble.dart';
import 'game_dialogs.dart';
import 'game_ingredient.dart';
import 'game_state.dart';
import 'game_ui.dart';

class CookingGameScreen extends StatefulWidget {
  const CookingGameScreen({super.key});

  @override
  State<CookingGameScreen> createState() => _CookingGameScreenState();
}

class _CookingGameScreenState extends State<CookingGameScreen>
    with TickerProviderStateMixin {
  late GameState _state;
  final AudioManager _audio = AudioManager();
  late AnimationController _shakeController;
  late AnimationController _cookTimerController;

  // Bowl state tracking
  bool _flourAdded = false;
  bool _bakingPowderAdded = false;
  bool _sugarAdded = false;
  bool _milkAdded = false;
  bool _eggAdded = false;
  bool _batcherMixed = false;
  bool _panSelected = false;
  bool _batterPoured = false;
  bool _pancakeFlipped = false;
  bool _pancakePlated = false;
  bool _syrupAdded = false;
  bool _butterAdded = false;

  double _whiskProgress = 0.0;
  bool _isWhisking = false;

  // Cook timer
  double _cookProgress = 0.0;
  Timer? _cookTimer;

  // Celebration
  bool _showCelebration = false;

  //Audio
  bool _disposed = false;

  //Screen
  late double _sw;
  late double _sh;

  //Bear
  late final double _bearHeight = _sh * 0.95;
  late final double _bearPosition = 0;

  //Table
  late final double _tableWidth = _sh * 0.22;
  late final double _tablePosition = -_sh * 0.60;

  //Milk
  late final double _milkLeftPosition = _sw * 0.20;
  late final double _milkBottomPosition = _sh * 0.05;
  late final double _milkSize = _sh * 0.40;

  //Sugar
  late final double _sugarLeftPosition = _sw * 0.11;
  late final double _sugarBottomPosition = _sh * 0;
  late final double _sugarSize = _sh * 0.27;

  //Baking Powder
  late final double _bakingPowderLeftPosition = _sw * 0.27;
  late final double _bakingPowderBottomPosition = _sh * 0;
  late final double _bakingPowderSize = _sh * 0.25;

  //Bowl
  late final double _bowlBottomPosition = 0;
  late final double _bowlLeftPosition = 0;
  late final double _bowlRightPosition = 0;
  late final double _bowlSize = _sh * 0.30;

  //Oil
  late final double _oilRightPosition = _sw * 0.13;
  late final double _oilBottomPosition = _sh * 0.01;
  late final double _oilSize = _sh * 0.34;

  //Flour
  late final double _flourLeftPosition = _sw * 0.65;
  late final double _flourBottomPosition = _sh * 0.01;
  late final double _flourSize = _sh * 0.32;

  //Egg
  late final double _eggLeftPosition = _sw * 0.60;
  late final double _eggBottomPosition = 0;
  late final double _eggSize = _sh * 0.18;

  @override
  void initState() {
    super.initState();
    _state = GameState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _cookTimerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _audio.playBgMusic();
    _showDialog(GameDialogs.intro1);
  }

  @override
  void dispose() {
    _disposed = true;
    _cookTimer?.cancel();
    _audio.stopAll();
    _shakeController.dispose();
    _cookTimerController.dispose();
    super.dispose();
  }

  // ─────────────────── Dialog helpers ─────────────────────

  void _showDialog(GameDialog dialog) {
    _audio.playVoice(dialog.audioFile);
    setState(() {
      _state = _state.copyWith(
        bearSpeechText: dialog.bearText,
        instructionText: dialog.instruction,
        showBearSpeech: true,
      );
    });
  }

  void _showWrongTap() {
    final dialogs = GameDialogs.wrongTapDialogs;
    final dialog = dialogs[Random().nextInt(dialogs.length)];
    //TODO _audio.playWrong();
    _showDialog(dialog);
    _shakeController.forward(from: 0);
  }

  // ─────────────────── Scene transitions ──────────────────

  void _advanceIntro() {
    switch (_state.dialogIndex) {
      case 0:
        setState(() => _state = _state.copyWith(dialogIndex: 1));
        _showDialog(GameDialogs.intro2);
      case 1:
        setState(() => _state = _state.copyWith(dialogIndex: 2));
        _showDialog(GameDialogs.intro3);
      default:
        setState(() {
          _state = _state.copyWith(
            currentScene: GameScene.dryIngredients,
            dialogIndex: 0,
            showBearSpeech: false,
          );
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_disposed || !mounted) return;
          _showDialog(GameDialogs.dryIngredients2);
        });
    }
  }

  // ─── DRY INGREDIENTS ───────────────────────────────────

  void _onFlourTap() {
    if (_flourAdded) return;
    //TODO _audio.playPour();
    setState(() => _flourAdded = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted) return;
      _showDialog(GameDialogs.dryIngredients3);
    });
  }

  void _onBakingPowderTap() {
    if (!_flourAdded) {
      _showWrongTap();
      return;
    }
    if (_bakingPowderAdded) return;
    //TODO _audio.playPour();
    setState(() => _bakingPowderAdded = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted) return;
      _showDialog(GameDialogs.dryIngredients4);
    });
  }

  void _onSugarTap() {
    if (!_bakingPowderAdded) {
      _showWrongTap();
      return;
    }
    if (_sugarAdded) return;
    //TODO _audio.playPour();
    setState(() => _sugarAdded = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted) return;
      _showDialog(GameDialogs.dryIngredients5);
      Future.delayed(const Duration(seconds: 2), () {
        if (_disposed || !mounted) return;
        setState(() {
          _state = _state.copyWith(
            currentScene: GameScene.wetIngredients,
            showBearSpeech: false,
          );
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_disposed || !mounted) return;
          _showDialog(GameDialogs.wetIngredients2);
        });
      });
    });
  }

  // ─── WET INGREDIENTS ───────────────────────────────────

  void _onMilkTap() {
    if (_milkAdded) return;
    //TODO _audio.playPour();
    setState(() => _milkAdded = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted) return;
      _showDialog(GameDialogs.wetIngredients3);
    });
  }

  void _onEggTap() {
    if (!_milkAdded) {
      _showWrongTap();
      return;
    }
    if (_eggAdded) return;
    //TODO   _audio.playCrack();
    setState(() => _eggAdded = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_disposed || !mounted) return;
      _showDialog(GameDialogs.wetIngredients4);
      Future.delayed(const Duration(seconds: 2), () {
        if (_disposed || !mounted) return;
        setState(() {
          _state = _state.copyWith(
            currentScene: GameScene.whisking,
            showBearSpeech: false,
          );
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_disposed || !mounted) return;
          _showDialog(GameDialogs.whisk2);
        });
      });
    });
  }

  // ─── WHISKING ──────────────────────────────────────────

  void _onWhiskProgress(double p) {
    setState(() => _whiskProgress = p);
    if (p > 0.5 && !_isWhisking) {
      _isWhisking = true;
      //TODO _audio.playWhisk();
    }
  }

  void _onWhiskComplete() {
    if (_batcherMixed) return;
    setState(() => _batcherMixed = true);
    _audio.playSfx('sfx_done.wav');
    _showDialog(GameDialogs.whisk4);
    Future.delayed(const Duration(seconds: 2), () {
      if (_disposed || !mounted) return;
      setState(() {
        _state = _state.copyWith(
          currentScene: GameScene.cooking,
          showBearSpeech: false,
        );
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_disposed || !mounted) return;
        _showDialog(GameDialogs.cook2);
      });
    });
  }

  // ─── COOKING ───────────────────────────────────────────

  void _onPanTap() {
    if (_panSelected) return;
    //TODO _audio.playTap();
    setState(() => _panSelected = true);
    _showDialog(GameDialogs.cook3);
  }

  void _onBowlTapForBatter() {
    if (!_panSelected) {
      _showWrongTap();
      return;
    }
    if (_batterPoured) return;
    //TODO _audio.playPour();
    setState(() => _batterPoured = true);
    _showDialog(GameDialogs.cook4);
    _startCookTimer(false);
  }

  void _startCookTimer(bool secondSide) {
    _cookProgress = 0;
    _cookTimer?.cancel();
    _cookTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_disposed || !mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cookProgress += 0.05 / 3);
      if (_cookProgress >= 1.0) {
        timer.cancel();
        if (!secondSide) {
          _showDialog(GameDialogs.cook5);
        } else {
          _showDialog(GameDialogs.cook7);
          Future.delayed(const Duration(seconds: 2), () {
            if (_disposed || !mounted) return;
            setState(() {
              _state = _state.copyWith(
                currentScene: GameScene.plating,
                showBearSpeech: false,
              );
            });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_disposed || !mounted) return;
              _showDialog(GameDialogs.plate1);
            });
          });
        }
      }
    });
  }

  void _onPanTapToFlip() {
    if (!_batterPoured || _pancakeFlipped) return;
    if (_cookProgress < 1.0) {
      _showWrongTap();
      return;
    }
    //TODO _audio.playFlip();
    setState(() {
      _pancakeFlipped = true;
      _cookProgress = 0;
    });
    _showDialog(GameDialogs.cook6);
    _startCookTimer(true);
  }

  // ─── PLATING ───────────────────────────────────────────

  void _onPlateTap() {
    if (_pancakePlated) return;
    //TODO _audio.playTap();
    setState(() => _pancakePlated = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_disposed || !mounted) return;
      _showDialog(GameDialogs.plate2);
    });
  }

  void _onSyrupTap() {
    if (!_pancakePlated) {
      _showWrongTap();
      return;
    }
    if (_syrupAdded) return;
    //TODO _audio.playDrizzle();
    setState(() => _syrupAdded = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_disposed || !mounted) return;
      _showDialog(GameDialogs.plate3);
    });
  }

  void _onButterTap() {
    if (!_syrupAdded) {
      _showWrongTap();
      return;
    }
    if (_butterAdded) return;
    //TODO _audio.playTap();
    setState(() => _butterAdded = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_disposed || !mounted) return;
      _showDialog(GameDialogs.plate4);
      Future.delayed(const Duration(seconds: 2), () {
        if (_disposed || !mounted) return;
        setState(() {
          _state = _state.copyWith(currentScene: GameScene.outro);
          _showCelebration = true;
        });
        //TODO _audio.playCelebration();
        _showDialog(GameDialogs.outro1);
      });
    });
  }

  // ─── OUTRO ─────────────────────────────────────────────

  void _onOutroTap() {
    switch (_state.dialogIndex) {
      case 0:
        setState(() => _state = _state.copyWith(dialogIndex: 1));
        _showDialog(GameDialogs.outro2);
      case 1:
        setState(() => _state = _state.copyWith(dialogIndex: 2));
        _showDialog(GameDialogs.outro3);
      default:
        _restartGame();
    }
  }

  void _restartGame() {
    _cookTimer?.cancel();
    setState(() {
      _state = GameState();
      _flourAdded = false;
      _bakingPowderAdded = false;
      _sugarAdded = false;
      _milkAdded = false;
      _eggAdded = false;
      _batcherMixed = false;
      _panSelected = false;
      _batterPoured = false;
      _pancakeFlipped = false;
      _pancakePlated = false;
      _syrupAdded = false;
      _butterAdded = false;
      _whiskProgress = 0.0;
      _isWhisking = false;
      _cookProgress = 0.0;
      _showCelebration = false;
    });
    _showDialog(GameDialogs.intro1);
  }

  // ─────────────────── BUILD ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    _sw = MediaQuery.of(context).size.width;
    _sh = MediaQuery.of(context).size.height;
    return Scaffold(
      body: GestureDetector(
        onTap: _state.currentScene == GameScene.intro
            ? _advanceIntro
            : _state.currentScene == GameScene.outro
            ? _onOutroTap
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Image.asset(
              'assets/images/backgrounds/bg_game_kitchen.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF3C8), Color(0xFFE8C97A)],
                  ),
                ),
              ),
            ),

            // Scene content
            _buildSceneContent(),

            // Speech bubble for mid-game scenes (no bear visible)
            if (_state.currentScene != GameScene.intro &&
                _state.currentScene != GameScene.cooking &&
                _state.currentScene != GameScene.outro &&
                _state.showBearSpeech &&
                _state.bearSpeechText.isNotEmpty)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Center(
                  child: BearSpeechBubble(
                    text: _state.bearSpeechText,
                    instruction: _state.instructionText,
                    visible: _state.showBearSpeech,
                  ),
                ),
              ),

            // Whisk progress bar
            if (_state.currentScene == GameScene.whisking && !_batcherMixed)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: CookingProgressBar(
                    progress: _whiskProgress,
                    label: 'Mix the batter!',
                    color: const Color(0xFFD4A853),
                  ),
                ),
              ),

            // Cook progress bar
            if (_state.currentScene == GameScene.cooking &&
                _batterPoured &&
                _cookProgress < 1.0)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: CookingProgressBar(
                    progress: _cookProgress,
                    label: _pancakeFlipped
                        ? 'Cooking other side...'
                        : 'Sizzling...',
                    color: Colors.orange,
                  ),
                ),
              ),

            // Celebration
            CelebrationOverlay(
              visible: _showCelebration && _state.dialogIndex < 2,
            ),
          ],
        ),
      ),
    );
  }

  // ─── SCENE BUILDERS ─────────────────────────────────────

  Widget _buildSceneContent() {
    switch (_state.currentScene) {
      case GameScene.intro:
        return _buildIntroScene();
      case GameScene.dryIngredients:
        return _buildDryIngredientsScene();
      case GameScene.wetIngredients:
        return _buildWetIngredientsScene();
      case GameScene.whisking:
        return _buildWhiskingScene();
      case GameScene.cooking:
        return _buildCookingScene();
      case GameScene.plating:
        return _buildPlatingScene();
      case GameScene.outro:
        return _buildOutroScene();
    }
  }

  // INTRO — Bear at table with all ingredients
  Widget _buildIntroScene() {
    return Stack(
      children: [
        // Bear behind table
        Positioned(
          bottom: _bearPosition,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/characters/little_bear_uniform.png',
              height: _bearHeight,
            ),
          ),
        ),

        // Table
        Positioned(
          bottom: _tablePosition,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/objects/lumi/table.png',
            width: _tableWidth,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) =>
                Container(height: _sh * 0.22, color: const Color(0xFFCD853F)),
          ),
        ),

        // Ingredients on top of table
        Positioned(
          bottom: _sh * 0.10,
          left: 0,
          right: 0,
          height: _sh * 0.28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _milkLeftPosition,
                bottom: _milkBottomPosition,
                child: _img('milk.png', _milkSize),
              ),
              Positioned(
                left: _sugarLeftPosition,
                bottom: _sugarBottomPosition,
                child: _img('sugar.png', _sugarSize),
              ),
              Positioned(
                left: _bakingPowderLeftPosition,
                bottom: _bakingPowderBottomPosition,
                child: _img('baking_powder.png', _bakingPowderSize),
              ),
              Positioned(
                left: _bowlLeftPosition,
                right: _bowlRightPosition,
                bottom: _bowlBottomPosition,
                child: _img('bowl.png', _bowlSize),
              ),
              Positioned(
                right: _oilRightPosition,
                bottom: _oilBottomPosition,
                child: _img('oil.png', _oilSize),
              ),
              Positioned(
                left: _flourLeftPosition,
                bottom: _flourBottomPosition,
                child: _img('flour.png', _flourSize),
              ),
              Positioned(
                left: _eggLeftPosition,
                bottom: _eggBottomPosition,
                child: _img('egg.png', _eggSize),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // DRY INGREDIENTS SCENE
  Widget _buildDryIngredientsScene() {
    return Stack(
      children: [
        //Bear
        Positioned(
          bottom: _bearPosition,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/characters/little_bear_uniform.png',
              height: _bearHeight,
            ),
          ),
        ),

        // Table surface
        Positioned(
          bottom: _tablePosition,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/objects/lumi/table.png',
            width: _tableWidth,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) =>
                Container(height: _sh * 0.22, color: const Color(0xFFCD853F)),
          ),
        ),

        // Bowl (center)
        Positioned(
          bottom: _bowlBottomPosition + _sh * 0.1,
          left: _bowlLeftPosition,
          right: _bowlRightPosition,
          child: Center(
            child: SizedBox(height: _bowlSize, child: _bowlState()),
          ),
        ),

        // Flour (left, active first)
        Positioned(
          bottom: _flourBottomPosition + _sh * 0.1,
          left: _flourLeftPosition,
          child: SizedBox(
            height: _flourSize,
            child: GameIngredient(
              id: 'flour',
              imagePath: 'assets/images/objects/lumi/flour.png',
              isActive: !_flourAdded,
              isVisible: !_flourAdded,
              animatePour: false,
              bounce: !_flourAdded && !_bakingPowderAdded,
              onTap: _onFlourTap,
            ),
          ),
        ),

        // Baking Powder
        Positioned(
          bottom: _bakingPowderBottomPosition + _sh * 0.1,
          left: _bakingPowderLeftPosition,
          child: SizedBox(
            height: _bakingPowderSize,
            child: GameIngredient(
              id: 'baking_powder',
              imagePath: 'assets/images/objects/lumi/baking_powder.png',
              isActive: _flourAdded && !_bakingPowderAdded,
              isVisible: !_bakingPowderAdded,
              bounce: _flourAdded && !_bakingPowderAdded,
              onTap: _onBakingPowderTap,
            ),
          ),
        ),

        // Sugar
        Positioned(
          bottom: _sugarBottomPosition + _sh * 0.1,
          left: _sugarLeftPosition,
          child: SizedBox(
            height: _sugarSize,
            child: GameIngredient(
              id: 'sugar',
              imagePath: 'assets/images/objects/lumi/sugar.png',
              isActive: _bakingPowderAdded && !_sugarAdded,
              isVisible: !_sugarAdded,
              bounce: _bakingPowderAdded && !_sugarAdded,
              onTap: _onSugarTap,
            ),
          ),
        ),

        // Speech bubble
        if (_state.showBearSpeech && _state.bearSpeechText.isNotEmpty)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Center(
              child: BearSpeechBubble(
                text: _state.bearSpeechText,
                instruction: _state.instructionText,
              ),
            ),
          ),
      ],
    );
  }

  // WET INGREDIENTS SCENE
  Widget _buildWetIngredientsScene() {
    return Stack(
      children: [
        //Bear
        Positioned(
          bottom: _bearPosition,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/characters/little_bear_uniform.png',
              height: _bearHeight,
            ),
          ),
        ),

        // Table
        Positioned(
          bottom: _tablePosition,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/objects/lumi/table.png',
            width: _tableWidth,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) =>
                Container(height: _sh * 0.22, color: const Color(0xFFCD853F)),
          ),
        ),

        // Bowl with dry contents
        Positioned(
          bottom: _bowlBottomPosition + _sh * 0.1,
          left: _bowlRightPosition,
          right: _bowlLeftPosition,
          child: Center(
            child: SizedBox(height: _bowlSize, child: _bowlState()),
          ),
        ),

        // Milk
        Positioned(
          bottom: _milkBottomPosition + _sh * 0.1,
          left: _milkLeftPosition,
          child: SizedBox(
            height: _milkSize,
            child: GameIngredient(
              id: 'milk',
              imagePath: 'assets/images/objects/lumi/milk.png',
              isActive: !_milkAdded,
              isVisible: !_milkAdded,
              bounce: !_milkAdded,
              onTap: _onMilkTap,
            ),
          ),
        ),

        // Egg
        Positioned(
          bottom: _eggBottomPosition + _sh * 0.1,
          left: _eggLeftPosition,
          child: SizedBox(
            height: _eggSize,
            child: GameIngredient(
              id: 'egg',
              imagePath: 'assets/images/objects/lumi/egg.png',
              isActive: _milkAdded && !_eggAdded,
              isVisible: !_eggAdded,
              bounce: _milkAdded && !_eggAdded,
              onTap: _onEggTap,
            ),
          ),
        ),
      ],
    );
  }

  // WHISKING SCENE
  Widget _buildWhiskingScene() {
    return Stack(
      children: [
        // Bear
        Positioned(
          bottom: _bearPosition,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/characters/little_bear_uniform.png',
              height: _bearHeight,
            ),
          ),
        ),

        // Table
        Positioned(
          bottom: _tablePosition,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/objects/lumi/table.png',
            width: _tableWidth,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) =>
                Container(height: _sh * 0.22, color: const Color(0xFFCD853F)),
          ),
        ),

        // Bowl with egg visible
        Positioned(
          bottom: _bowlBottomPosition + _sh * 0.1,
          left: _bowlRightPosition,
          right: _bowlLeftPosition,
          child: Center(
            child: SizedBox(
              height: _bowlSize,
              child: Image.asset(
                _batcherMixed
                    ? 'assets/images/objects/lumi/bowl_mixed_ingredients.png'
                    : 'assets/images/objects/lumi/bowl_dry_ingredients_egg.png',
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => const Icon(
                  Icons.soup_kitchen,
                  size: 100,
                  color: Color(0xFFD4A853),
                ),
              ),
            ),
          ),
        ),

        // Whisk (draggable) — only shown when mixing needed
        if (!_batcherMixed)
          Positioned(
            bottom: _sh * 0.18,
            left: 0,
            right: 0,
            child: Center(
              child: WhiskWidget(
                progress: _whiskProgress,
                onProgress: _onWhiskProgress,
                onComplete: _onWhiskComplete,
              ),
            ),
          ),
      ],
    );
  }

  // COOKING SCENE
  Widget _buildCookingScene() {
    return Stack(
      children: [
        // Bear
        Positioned(
          bottom: _bearPosition,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/characters/little_bear_uniform.png',
              height: _bearHeight,
            ),
          ),
        ),

        // Table lower portion
        Positioned(
          bottom: _tablePosition,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/objects/lumi/table.png',
            width: _tableWidth,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) =>
                Container(height: _sh * 0.22, color: const Color(0xFFCD853F)),
          ),
        ),

        // Pan
        Positioned(
          bottom: _sh * 0.10,
          left: _sw * 0.15,
          child: GestureDetector(
            onTap: !_panSelected
                ? _onPanTap
                : (_batterPoured && _cookProgress >= 1.0 && !_pancakeFlipped
                      ? _onPanTapToFlip
                      : null),
            child:
                Image.asset(
                      'assets/images/objects/lumi/pan.png',
                      width: _sw * 0.28,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, st) => const Icon(
                        Icons.circle,
                        size: 100,
                        color: Colors.grey,
                      ),
                    )
                    .animate(target: _panSelected ? 1 : 0)
                    .tint(color: Colors.orange.withValues(alpha: 0.3)),
          ),
        ),

        // Bowl of batter (tap to pour)
        if (!_batterPoured)
          Positioned(
            bottom: _bowlBottomPosition + _sh * 0.1,
            right: _sw * 0.18,
            child: GestureDetector(
              onTap: _onBowlTapForBatter,
              child: Image.asset(
                'assets/images/objects/lumi/bowl_mixed_ingredients.png',
                height: _bowlSize,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => const Icon(
                  Icons.soup_kitchen,
                  size: 80,
                  color: Color(0xFFD4A853),
                ),
              ),
            ),
          ),

        // Pancake cooking visual
        if (_batterPoured)
          Positioned(
            bottom: _sh * 0.13,
            left: _sw * 0.18,
            child: Image.asset(
              'assets/images/objects/lumi/pancake.png',
              width: _sw * 0.18,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) =>
                  const Icon(Icons.circle, size: 90, color: Color(0xFFE8A037)),
            ),
          ),
      ],
    );
  }

  // PLATING SCENE
  Widget _buildPlatingScene() {
    String pancakeAsset = 'assets/images/objects/lumi/pancake.png';
    if (_syrupAdded && _butterAdded) {
      pancakeAsset = 'assets/images/objects/lumi/pancke_maple_syrup_butter.png';
    } else if (_syrupAdded) {
      pancakeAsset = 'assets/images/objects/lumi/pancake_maple_syrup.png';
    }

    return Stack(
      children: [
        // Bear behind table
        Positioned(
          bottom: _bearPosition,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/characters/little_bear_uniform.png',
              height: _bearHeight,
            ),
          ),
        ),

        // Table
        Positioned(
          bottom: _tablePosition,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/objects/lumi/table.png',
            width: _tableWidth,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) =>
                Container(height: _sh * 0.22, color: const Color(0xFFCD853F)),
          ),
        ),

        // Plate + Pancake (center)
        Positioned(
          bottom: _sh * 0.065,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: !_pancakePlated ? _onPlateTap : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/objects/lumi/plate.png',
                    width: _sw * 0.30,
                    errorBuilder: (ctx, err, st) => Container(
                      width: 220,
                      height: 20,
                      color: Colors.white70,
                    ),
                  ),
                  if (_pancakePlated)
                    Image.asset(
                      pancakeAsset,
                      width: _sw * 0.20,
                      errorBuilder: (ctx, err, st) => const Icon(
                        Icons.circle,
                        size: 120,
                        color: Color(0xFFE8A037),
                      ),
                    ).animate().scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                    ),
                ],
              ),
            ),
          ),
        ),

        // Maple Syrup
        if (_pancakePlated && !_syrupAdded)
          Positioned(
            bottom: _sh * 0.1,
            right: _sw * 0.1,
            child: SizedBox(
              height: _sh * 0.4,
              child: GameIngredient(
                id: 'syrup',
                imagePath: 'assets/images/objects/lumi/maple_syrup.png',
                isActive: true,
                bounce: true,
                onTap: _onSyrupTap,
              ),
            ),
          ),

        // Butter
        if (_syrupAdded && !_butterAdded)
          Positioned(
            bottom: _sh * 0.1,
            left: _sw * 0.15,
            child: SizedBox(
              height: _sh * 0.2,
              child: GameIngredient(
                id: 'butter',
                imagePath: 'assets/images/objects/lumi/butter.png',
                isActive: true,
                bounce: true,
                onTap: _onButterTap,
              ),
            ),
          ),

        // Speech bubble
        if (_state.showBearSpeech && _state.bearSpeechText.isNotEmpty)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Center(
              child: BearSpeechBubble(
                text: _state.bearSpeechText,
                instruction: _state.instructionText,
              ),
            ),
          ),
      ],
    );
  }

  // OUTRO SCENE
  Widget _buildOutroScene() {
    return Stack(
      children: [
        // Bear behind table
        Positioned(
          bottom: _bearPosition,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/characters/little_bear_uniform.png',
              height: _bearHeight,
            ),
          ),
        ),

        // Table
        Positioned(
          bottom: _tablePosition,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/objects/lumi/table.png',
            width: _tableWidth,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) =>
                Container(height: _sh * 0.22, color: const Color(0xFFCD853F)),
          ),
        ),

        // Plate
        Positioned(
          bottom: _sh * 0.065,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/objects/lumi/plate.png',
              width: _sw * 0.30, // same as plating scene
              errorBuilder: (ctx, err, st) => const SizedBox(),
            ),
          ),
        ),

        // Pancake on plate
        Positioned(
          bottom: _sh * 0.075,
          left: 0,
          right: 0,
          child: Center(
            child:
                Image.asset(
                  'assets/images/objects/lumi/pancke_maple_syrup_butter.png',
                  width: _sw * 0.20, // same as plating scene
                  errorBuilder: (ctx, err, st) =>
                      const Text('🥞', style: TextStyle(fontSize: 100)),
                ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                ),
          ),
        ),

        // Play again button
        if (_state.dialogIndex >= 2)
          GoodJobOverlay(
            characterImage: 'assets/images/characters/dr.woo_the_owl.png',
            closeButtonColor: const Color(0xFFFF9D3E),
            onNext: () {
              // TODO: navigate to next level
            },
            onRestart: _restartGame,
            onBack: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
                (route) => route.isFirst,
              );
            },
          ),
      ],
    );
  }

  // ─── Helper: bowl state image ─────────────────────────

  Widget _bowlState() {
    String asset = 'assets/images/objects/lumi/bowl.png';
    if (_eggAdded) {
      asset = 'assets/images/objects/lumi/bowl_dry_ingredients_egg.png';
    } else if (_milkAdded) {
      asset = 'assets/images/objects/lumi/bowl_dry_ingredients_milk.png';
    } else if (_sugarAdded) {
      asset = 'assets/images/objects/lumi/bowl_dry_ingredients3.png';
    } else if (_bakingPowderAdded) {
      asset = 'assets/images/objects/lumi/bowl_dry_ingredients2.png';
    } else if (_flourAdded) {
      asset = 'assets/images/objects/lumi/bowl_dry_ingredients1.png';
    }

    return Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, st) => const Icon(
            Icons.soup_kitchen,
            size: 100,
            color: Color(0xFFD4A853),
          ),
        )
        .animate(key: ValueKey(asset))
        .fadeIn(duration: const Duration(milliseconds: 300));
  }

  // ─── Helper: simple image ────────────────────────────

  Widget _img(String filename, double height, {double? width}) {
    return Image.asset(
      'assets/images/objects/lumi/$filename',
      height: height,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, st) => SizedBox(
        width: 60,
        height: height,
        child: const Icon(Icons.image_not_supported),
      ),
    );
  }
}
