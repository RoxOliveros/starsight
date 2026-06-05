class GameDialog {
  final String id;
  final String bearText;
  final String? instruction;
  final String audioFile;

  const GameDialog({
    required this.id,
    required this.bearText,
    this.instruction,
    required this.audioFile,
  });
}

class GameDialogs {
  // ─────────────────────────────────────────────
  //  SCENE 1 — INTRO
  // ─────────────────────────────────────────────
  static const intro1 = GameDialog(
    id: 'intro_1',
    bearText: '',
    instruction: null,
    audioFile: 'intro_1.wav',
  );

  static const intro2 = GameDialog(
    id: 'intro_2',
    bearText: '',
    instruction: null,
    audioFile: 'intro_2.wav',
  );

  static const intro3 = GameDialog(
    id: 'intro_3',
    bearText: '',
    instruction: null,
    audioFile: 'intro_3.wav',
  );

  // ─────────────────────────────────────────────
  //  SCENE 2 — ADD DRY INGREDIENTS
  // ─────────────────────────────────────────────
  static const dryIngredients1 = GameDialog(
    id: 'dry_1',
    bearText: '',
    instruction: null,
    audioFile: 'dry_1.wav',
  );

  static const dryIngredients2 = GameDialog(
    id: 'dry_2',
    bearText: '',
    instruction: null,
    audioFile: 'dry_2.wav',
  );

  static const dryIngredients3 = GameDialog(
    id: 'dry_3',
    bearText: '',
    instruction: null,
    audioFile: 'dry_3.wav',
  );

  static const dryIngredients4 = GameDialog(
    id: 'dry_4',
    bearText: '',
    instruction: null,
    audioFile: 'dry_4.wav',
  );

  static const dryIngredients5 = GameDialog(
    id: 'dry_5',
    bearText: '',
    instruction: null,
    audioFile: 'dry_5.wav',
  );

  // ─────────────────────────────────────────────
  //  SCENE 3 — ADD WET INGREDIENTS
  // ─────────────────────────────────────────────
  static const wetIngredients1 = GameDialog(
    id: 'wet_1',
    bearText: '',
    instruction: null,
    audioFile: 'wet_1.wav',
  );

  static const wetIngredients2 = GameDialog(
    id: 'wet_2',
    bearText: '',
    instruction: null,
    audioFile: 'wet_2.wav',
  );

  static const wetIngredients3 = GameDialog(
    id: 'wet_3',
    bearText: '',
    instruction: null,
    audioFile: 'wet_3.wav',
  );

  static const wetIngredients4 = GameDialog(
    id: 'magaling',
    bearText: '',
    instruction: null,
    audioFile: 'magaling.wav',
  );

  // ─────────────────────────────────────────────
  //  SCENE 4 — WHISK THE BATTER
  // ─────────────────────────────────────────────
  static const whisk1 = GameDialog(
    id: 'whisk_1',
    bearText: '',
    instruction: null,
    audioFile: 'whisk_1.wav',
  );

  static const whisk2 = GameDialog(
    id: 'whisk_2',
    bearText: '',
    instruction: null,
    audioFile: 'whisk_2.wav',
  );

  static const whisk3 = GameDialog(
    id: 'whisk_3',
    bearText: '',
    instruction: null,
    audioFile: 'whisk_3.wav',
  );

  static const whisk4 = GameDialog(
    id: 'whisk_4',
    bearText: '',
    instruction: null,
    audioFile: 'whisk_4.wav',
  );

  // ─────────────────────────────────────────────
  //  SCENE 5 — COOK ON PAN
  // ─────────────────────────────────────────────
  static const cook1 = GameDialog(
    id: 'cook_1',
    bearText: '',
    instruction: null,
    audioFile: 'cook_1.wav',
  );

  static const cook2 = GameDialog(
    id: 'cook_2',
    bearText: '',
    instruction: null,
    audioFile: 'cook_2.wav',
  );

  static const cook3 = GameDialog(
    id: 'cook_3',
    bearText: '',
    instruction: null,
    audioFile: 'cook_3.wav',
  );

  static const cook4 = GameDialog(
    id: 'cook_4',
    bearText: '',
    instruction: null,
    audioFile: 'cook_4.wav',
  );

  static const cook5 = GameDialog(
    id: 'cook_5',
    bearText: '',
    instruction: null,
    audioFile: 'cook_5.wav',
  );

  static const cook6 = GameDialog(
    id: 'cook_6',
    bearText: '',
    instruction: null,
    audioFile: 'cook_6.wav',
  );

  static const cook7 = GameDialog(
    id: 'cook_7',
    bearText: '',
    instruction: null,
    audioFile: 'cook_7.wav',
  );

  // ─────────────────────────────────────────────
  //  SCENE 6 — PLATE & TOPPINGS
  // ─────────────────────────────────────────────
  static const plate1 = GameDialog(
    id: 'plate_1',
    bearText: '',
    instruction: null,
    audioFile: 'plate_1.wav',
  );

  static const plate2 = GameDialog(
    id: 'plate_2',
    bearText: '',
    instruction: null,
    audioFile: 'plate_2.wav',
  );

  static const plate3 = GameDialog(
    id: 'plate_3',
    bearText: '',
    instruction: null,
    audioFile: 'plate_3.wav',
  );

  static const plate4 = GameDialog(
    id: 'plate_4',
    bearText: '',
    instruction: null,
    audioFile: 'plate_4.wav',
  );

  // ─────────────────────────────────────────────
  //  SCENE 7 — OUTRO / CELEBRATION
  // ─────────────────────────────────────────────
  static const outro1 = GameDialog(
    id: 'outro_1',
    bearText: '',
    instruction: null,
    audioFile: 'outro_1.wav',
  );

  static const outro2 = GameDialog(
    id: 'outro_2',
    bearText: '',
    instruction: null,
    audioFile: 'outro_2.wav',
  );

  static const outro3 = GameDialog(
    id: 'outro_3',
    bearText: '',
    instruction: null,
    audioFile: 'outro_3.wav',
  );

  // ─────────────────────────────────────────────
  //  WRONG TAP REACTIONS (Random pick)
  // ─────────────────────────────────────────────
  static const wrongTap1 = GameDialog(
    id: 'wrong_1',
    bearText: '',
    instruction: null,
    audioFile: 'wrong_1.wav',
  );

  static const wrongTap2 = GameDialog(
    id: 'wrong_2',
    bearText: '',
    instruction: null,
    audioFile: 'wrong_2.wav',
  );

  static const wrongTap3 = GameDialog(
    id: 'wrong_3',
    bearText: '',
    instruction: null,
    audioFile: 'wrong_3.wav',
  );

  static const List<GameDialog> wrongTapDialogs = [
    wrongTap1,
    wrongTap2,
    wrongTap3,
  ];

  // ─────────────────────────────────────────────
  //  ENCOURAGE REACTIONS (Random pick)
  // ─────────────────────────────────────────────
  static const encourage1 = GameDialog(
    id: 'enc_1',
    bearText: '',
    instruction: null,
    audioFile: 'encourage_1.wav',
  );

  static const encourage2 = GameDialog(
    id: 'enc_2',
    bearText: '',
    instruction: null,
    audioFile: 'encourage_2.wav',
  );

  static const encourage3 = GameDialog(
    id: 'enc_3',
    bearText: '',
    instruction: null,
    audioFile: 'encourage_3.wav',
  );

  static const List<GameDialog> encourageDialogs = [
    encourage1,
    encourage2,
    encourage3,
  ];
}
