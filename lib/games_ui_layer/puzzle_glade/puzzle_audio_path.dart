class PuzzleAudioPath {
  PuzzleAudioPath._();

  static const String base = 'assets/audio/puzzle_glade';
  static const String sfxBase = 'assets/audio/sound_effects';

  static const String circle = '$base/circle.wav';
  static const String square = '$base/square.wav';
  static const String triangle = '$base/triangle.wav';
  static const String rectangle = '$base/rectangle.wav';
  static const String star = '$base/star.wav';
  static const String heart = '$base/heart.wav';

  static String forShape(String shapeName) {
    switch (shapeName) {
      case 'circle':
        return circle;
      case 'square':
        return square;
      case 'triangle':
        return triangle;
      case 'rectangle':
        return rectangle;
      case 'star':
        return star;
      case 'heart':
        return heart;
      default:
        throw ArgumentError('Unknown shape: $shapeName');
    }
  }
}