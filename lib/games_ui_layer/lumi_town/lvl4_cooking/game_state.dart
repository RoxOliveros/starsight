// lib/models/game_state.dart

enum GameScene {
  intro,
  dryIngredients,
  wetIngredients,
  whisking,
  cooking,
  plating,
  outro,
}

enum CookingStep {
  // Dry ingredients
  addFlour,
  addBakingPowder,
  addSugar,
  dryDone,

  // Wet ingredients
  addMilk,
  addEgg,
  wetDone,

  // Whisk
  whisking,
  whiskDone,

  // Cook
  getPan,
  pourBatter,
  cooking,
  flip,
  cookingSecondSide,
  cookDone,

  // Plate
  plate,
  addSyrup,
  addButter,
  plateDone,
}

class GameState {
  GameScene currentScene;
  CookingStep currentStep;
  int dialogIndex;
  bool isAnimating;
  bool showBearSpeech;
  String bearSpeechText;
  String? instructionText;
  double whiskProgress; // 0.0 to 1.0
  bool pancakeFlipped;

  GameState({
    this.currentScene = GameScene.intro,
    this.currentStep = CookingStep.addFlour,
    this.dialogIndex = 0,
    this.isAnimating = false,
    this.showBearSpeech = false,
    this.bearSpeechText = '',
    this.instructionText,
    this.whiskProgress = 0.0,
    this.pancakeFlipped = false,
  });

  GameState copyWith({
    GameScene? currentScene,
    CookingStep? currentStep,
    int? dialogIndex,
    bool? isAnimating,
    bool? showBearSpeech,
    String? bearSpeechText,
    String? instructionText,
    double? whiskProgress,
    bool? pancakeFlipped,
  }) {
    return GameState(
      currentScene: currentScene ?? this.currentScene,
      currentStep: currentStep ?? this.currentStep,
      dialogIndex: dialogIndex ?? this.dialogIndex,
      isAnimating: isAnimating ?? this.isAnimating,
      showBearSpeech: showBearSpeech ?? this.showBearSpeech,
      bearSpeechText: bearSpeechText ?? this.bearSpeechText,
      instructionText: instructionText ?? this.instructionText,
      whiskProgress: whiskProgress ?? this.whiskProgress,
      pancakeFlipped: pancakeFlipped ?? this.pancakeFlipped,
    );
  }
}
