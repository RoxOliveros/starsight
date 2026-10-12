class ForestAudioAssets {
  ForestAudioAssets._();

  static const String base = 'assets/audio/alphabet_forest';

  static String forLetter(String letter) {
    final l = letter.toLowerCase();
    if (l.length != 1 || l.codeUnitAt(0) < 97 || l.codeUnitAt(0) > 122) {
      throw ArgumentError('Unknown letter: $letter');
    }
    return '$base/sound_effects/sound_$l.wav';
  }
}