

// ── Toy model ─────────────────────────────────────────────────────────────────

import 'dart:ui';

class ToyItem {
  final String id;
  final String imagePath;
  final String audioPath;

  const ToyItem({
    required this.id,
    required this.imagePath,
    required this.audioPath,
  });
}

// ── All 12 toys ───────────────────────────────────────────────────────────────

const List<ToyItem> kAllToys = [
  ToyItem(
    id: 'airplane',
    imagePath: 'assets/images/objects/lumi/airplane.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_airplane.wav',
  ),
  ToyItem(
    id: 'cap',
    imagePath: 'assets/images/objects/lumi/cap.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_cap.wav',
  ),
  ToyItem(
    id: 'dinosaur',
    imagePath: 'assets/images/objects/lumi/dinosaur.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_dinosaur.wav',
  ),
  ToyItem(
    id: 'doll',
    imagePath: 'assets/images/objects/lumi/doll.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_doll.wav',
  ),
  ToyItem(
    id: 'jar',
    imagePath: 'assets/images/objects/lumi/jar.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_jar.wav',
  ),
  ToyItem(
    id: 'key',
    imagePath: 'assets/images/objects/lumi/key.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_key.wav',
  ),
  ToyItem(
    id: 'stacking_toy',
    imagePath: 'assets/images/objects/lumi/stacking_toy.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_stacking_toy.wav',
  ),
  ToyItem(
    id: 'train',
    imagePath: 'assets/images/objects/lumi/train.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_train.wav',
  ),
  ToyItem(
    id: 'umbrella',
    imagePath: 'assets/images/objects/lumi/umbrella.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_umbrella.wav',
  ),
  ToyItem(
    id: 'xylophone',
    imagePath: 'assets/images/objects/lumi/xylophone.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_xylophone.wav',
  ),
  ToyItem(
    id: 'yarn',
    imagePath: 'assets/images/objects/lumi/yarn.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_yarn.wav',
  ),
  ToyItem(
    id: 'yoyo',
    imagePath: 'assets/images/objects/lumi/yoyo.png',
    audioPath: 'assets/audio/lumi_town/level3/vo_yoyo.wav',
  ),
];

// ── 4 rounds of 3 toys each ───────────────────────────────────────────────────
// Each sub-list is toy IDs for that round.

const List<List<String>> kRounds = [
  ['doll', 'cap', 'xylophone'],
  ['dinosaur', 'train', 'yarn'],
  ['airplane', 'yoyo', 'umbrella'],
  ['jar', 'key', 'stacking_toy'],
];

const List<List<String>> kRoundTargets = [
  ['doll', 'cap', 'xylophone'],      // round 1 targets
  ['dinosaur', 'train', 'yarn'],     // round 2 targets
  ['airplane', 'yoyo', 'umbrella'],  // round 3 targets
  ['jar', 'key', 'stacking_toy'],    // round 4 targets
];

// All toys start visible, removed as they're placed
const List<String> kAllToyIds = [
  'airplane', 'cap', 'dinosaur', 'doll',
  'jar', 'key', 'stacking_toy', 'train',
  'umbrella', 'xylophone', 'yarn', 'yoyo',
];

// ── Fixed scatter positions (as fractions of screen width/height) ─────────────
// 3 toys per round — left, center, right zones on the scene.
// These are [dx, dy] fractions: dx=0 is left edge, dy=0 is top edge.

const List<_ToyPosition> kToyPositions = [
  _ToyPosition(dxFraction: 0.18, dyFraction: 0.52), // left — floor area
  _ToyPosition(dxFraction: 0.38, dyFraction: 0.60), // center — rug area
  _ToyPosition(dxFraction: 0.58, dyFraction: 0.55), // right-center — floor
];

class _ToyPosition {
  final double dxFraction;
  final double dyFraction;
  const _ToyPosition({required this.dxFraction, required this.dyFraction});
}

// ── Helper: get ToyItem by id ─────────────────────────────────────────────────

ToyItem toyById(String id) {
  return kAllToys.firstWhere((t) => t.id == id);
}

// ── Helper: get positions scaled to actual screen size ───────────────────────

List<Offset> scaledPositions(Size screenSize) {
  return kToyPositions.map((p) {
    // Subtract half the toy icon size (60) so it centers on the position point.
    // The toy icon size itself is responsive (see BedroomRoundScreen).
    return Offset(
      p.dxFraction * screenSize.width,
      p.dyFraction * screenSize.height,
    );
  }).toList();
}
