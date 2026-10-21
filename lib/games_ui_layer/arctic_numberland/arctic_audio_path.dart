class ArcticAudioPath {
  ArcticAudioPath._();

  static const String base = 'assets/audio/arctic_numberland';
  static const String circle = '$base/circle.wav';
  static const String square = '$base/square.wav';
  static const String triangle = '$base/triangle.wav';
  static const String star = '$base/star.wav';

  static const String red = '$base/red.wav';
  static const String blue = '$base/blue.wav';
  static const String green = '$base/green.wav';
  static const String yellow = '$base/yellow.wav';
  static const String purple = '$base/purple.wav';

  static String forShape(String shapeName) {
    switch (shapeName) {
      case 'circle':
        return circle;
      case 'square':
        return square;
      case 'triangle':
        return triangle;
      case 'star':
        return star;
      default:
        throw ArgumentError('Unknown shape: $shapeName');
    }
  }

  static String forColor(String colorName) {
    switch (colorName) {
      case 'red':
        return red;
      case 'blue':
        return blue;
      case 'green':
        return green;
      case 'yellow':
        return yellow;
      case 'purple':
        return purple;
      default:
        throw ArgumentError('Unknown color: $colorName');
    }
  }
}