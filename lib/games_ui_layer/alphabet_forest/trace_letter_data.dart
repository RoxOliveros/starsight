import 'package:flutter/material.dart';

class TraceLevel {
  final String letterName;
  final String imagePath;
  final List<List<Offset>> strokes;

  TraceLevel({
    required this.letterName,
    required this.imagePath,
    required this.strokes,
  });
}

class TraceStep {
  final String letter;
  final TraceLevel trace;
  const TraceStep(this.letter, this.trace);
}

class TraceData {
  static List<TraceLevel> forLetter(String letter) {
    switch (letter.toUpperCase()) {
      case 'A':
        return [
          TraceLevel(
            letterName: "Big A",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.2), const Offset(0.2, 0.8)],
              [const Offset(0.5, 0.2), const Offset(0.8, 0.8)],
              [const Offset(0.35, 0.5), const Offset(0.65, 0.5)],
            ],
          ),
          TraceLevel(
            letterName: "Small a",
            imagePath: '',
            strokes: [
              [
                const Offset(0.66, 0.48),
                const Offset(0.56, 0.41),
                const Offset(0.44, 0.42),
                const Offset(0.35, 0.52),
                const Offset(0.34, 0.66),
                const Offset(0.42, 0.77),
                const Offset(0.54, 0.80),
                const Offset(0.66, 0.74),
              ],
              [const Offset(0.66, 0.40), const Offset(0.66, 0.80)],
            ],
          ),
        ];

      case 'B':
        return [
          TraceLevel(
            letterName: "Big B",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.7, 0.35),
                const Offset(0.6, 0.5),
                const Offset(0.3, 0.5),
              ], // Top Loop
              [
                const Offset(0.3, 0.5),
                const Offset(0.65, 0.5),
                const Offset(0.75, 0.65),
                const Offset(0.65, 0.8),
                const Offset(0.3, 0.8),
              ], // Bot Loop
            ],
          ),
          TraceLevel(
            letterName: "Small b",
            imagePath: '',
            strokes: [
              [const Offset(0.34, 0.20), const Offset(0.34, 0.80)],
              [
                const Offset(0.34, 0.50),
                const Offset(0.42, 0.42),
                const Offset(0.54, 0.40),
                const Offset(0.64, 0.48),
                const Offset(0.67, 0.60),
                const Offset(0.64, 0.72),
                const Offset(0.54, 0.80),
                const Offset(0.42, 0.78),
                const Offset(0.34, 0.70),
              ],
            ],
          ),
        ];

      case 'C':
        return [
          TraceLevel(
            letterName: "Big C",
            imagePath: '',
            strokes: [
              [
                const Offset(0.70, 0.30),
                const Offset(0.60, 0.22),
                const Offset(0.48, 0.20),
                const Offset(0.37, 0.28),
                const Offset(0.31, 0.50),
                const Offset(0.37, 0.72),
                const Offset(0.48, 0.80),
                const Offset(0.60, 0.78),
                const Offset(0.70, 0.70),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small c",
            imagePath: '',
            strokes: [
              [
                const Offset(0.64, 0.48),
                const Offset(0.56, 0.42),
                const Offset(0.46, 0.41),
                const Offset(0.38, 0.47),
                const Offset(0.34, 0.60),
                const Offset(0.38, 0.73),
                const Offset(0.46, 0.79),
                const Offset(0.56, 0.78),
                const Offset(0.64, 0.72),
              ],
            ],
          ),
        ];

      case 'D':
        return [
          TraceLevel(
            letterName: "Big D",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.75, 0.5),
                const Offset(0.6, 0.8),
                const Offset(0.3, 0.8),
              ], // Big Loop
            ],
          ),
          TraceLevel(
            letterName: "Small d",
            imagePath: '',
            strokes: [
              [
                const Offset(0.66, 0.48),
                const Offset(0.56, 0.41),
                const Offset(0.44, 0.42),
                const Offset(0.35, 0.52),
                const Offset(0.34, 0.66),
                const Offset(0.42, 0.77),
                const Offset(0.54, 0.80),
                const Offset(0.66, 0.74),
              ],
              [const Offset(0.66, 0.20), const Offset(0.66, 0.80)],
            ],
          ),
        ];

      case 'E':
        return [
          TraceLevel(
            letterName: "Big E",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [const Offset(0.3, 0.2), const Offset(0.65, 0.2)], // Top
              [const Offset(0.3, 0.5), const Offset(0.55, 0.5)], // Mid
              [const Offset(0.3, 0.8), const Offset(0.65, 0.8)], // Bot
            ],
          ),
          TraceLevel(
            letterName: "Small e",
            imagePath: '',
            strokes: [
              [
                const Offset(0.34, 0.60),
                const Offset(0.50, 0.60),
                const Offset(0.66, 0.60),
                const Offset(0.63, 0.48),
                const Offset(0.52, 0.41),
                const Offset(0.40, 0.45),
                const Offset(0.33, 0.60),
                const Offset(0.38, 0.74),
                const Offset(0.50, 0.80),
                const Offset(0.64, 0.75),
              ],
            ],
          ),
        ];

      case 'F':
        return [
          TraceLevel(
            letterName: "Big F",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Vertical
              [const Offset(0.3, 0.2), const Offset(0.65, 0.2)], // Top
              [const Offset(0.3, 0.5), const Offset(0.55, 0.5)], // Mid
            ],
          ),
          TraceLevel(
            letterName: "Small f",
            imagePath: '',
            strokes: [
              [
                const Offset(0.60, 0.25),
                const Offset(0.50, 0.15),
                const Offset(0.40, 0.25),
                const Offset(0.40, 0.85),
              ],
              [
                const Offset(0.25, 0.45),
                const Offset(0.55, 0.45),
              ],
            ],
          ),
        ];

      case 'G':
        return [
          TraceLevel(
            letterName: "Big G",
            imagePath: '',
            strokes: [
              [
                const Offset(0.70, 0.30),
                const Offset(0.60, 0.22),
                const Offset(0.48, 0.20),
                const Offset(0.37, 0.28),
                const Offset(0.31, 0.50),
                const Offset(0.37, 0.72),
                const Offset(0.48, 0.80),
                const Offset(0.60, 0.78),
                const Offset(0.69, 0.70),
                const Offset(0.70, 0.56),
                const Offset(0.60, 0.55),
                const Offset(0.52, 0.55),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small g",
            imagePath: '',
            strokes: [
              [
                const Offset(0.66, 0.36),
                const Offset(0.56, 0.29),
                const Offset(0.44, 0.30),
                const Offset(0.35, 0.40),
                const Offset(0.34, 0.54),
                const Offset(0.42, 0.65),
                const Offset(0.54, 0.68),
                const Offset(0.66, 0.62),
              ],
              [
                const Offset(0.66, 0.28),
                const Offset(0.66, 0.70),
                const Offset(0.60, 0.80),
                const Offset(0.48, 0.83),
                const Offset(0.38, 0.78),
              ],
            ],
          ),
        ];

      case 'H':
        return [
          TraceLevel(
            letterName: "Big H",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Left vertical
              [
                const Offset(0.7, 0.2),
                const Offset(0.7, 0.8),
              ], // Right vertical
              [const Offset(0.3, 0.5), const Offset(0.7, 0.5)], // Crossbar
            ],
          ),
          TraceLevel(
            letterName: "Small h",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Tall vertical
              [
                const Offset(0.3, 0.5),
                const Offset(0.5, 0.45),
                const Offset(0.65, 0.55),
                const Offset(0.65, 0.8),
              ], // Arch down
            ],
          ),
        ];

      case 'I':
        return [
          TraceLevel(
            letterName: "Big I",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.2),
                const Offset(0.7, 0.2),
              ], // Top horizontal
              [
                const Offset(0.3, 0.8),
                const Offset(0.7, 0.8),
              ], // Bottom horizontal
              [
                const Offset(0.5, 0.2),
                const Offset(0.5, 0.8),
              ], // Middle vertical
            ],
          ),
          TraceLevel(
            letterName: "Small i",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.4), const Offset(0.5, 0.8)], // Stem
              [
                const Offset(0.5, 0.25),
                const Offset(0.5, 0.26),
              ], // Dot (tiny stroke)
            ],
          ),
        ];

      case 'J':
        return [
          TraceLevel(
            letterName: "Big J",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.2),
                const Offset(0.7, 0.2),
              ], // Top horizontal
              [
                const Offset(0.5, 0.2),
                const Offset(0.5, 0.7),
                const Offset(0.4, 0.8),
                const Offset(0.3, 0.7),
              ], // Stem & hook
            ],
          ),
          TraceLevel(
            letterName: "Small j",
            imagePath: '',
            strokes: [
              [
                const Offset(0.5, 0.4),
                const Offset(0.5, 0.8),
                const Offset(0.4, 0.9),
                const Offset(0.3, 0.85),
              ], // Stem & hook
              [const Offset(0.5, 0.25), const Offset(0.5, 0.26)], // Dot
            ],
          ),
        ];

      case 'K':
        return [
          TraceLevel(
            letterName: "Big K",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)],
              [const Offset(0.7, 0.2), const Offset(0.3, 0.5)],
              [const Offset(0.3, 0.5), const Offset(0.7, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small k",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)],
              [const Offset(0.6, 0.45), const Offset(0.3, 0.6)],
              [const Offset(0.3, 0.6), const Offset(0.6, 0.8)],
            ],
          ),
        ];

      case 'L':
        return [
          TraceLevel(
            letterName: "Big L",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)],
              [const Offset(0.3, 0.8), const Offset(0.7, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small l",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.2), const Offset(0.5, 0.8)],
            ],
          ),
        ];

      case 'M':
        return [
          TraceLevel(
            letterName: "Big M",
            imagePath: '',
            strokes: [
              [const Offset(0.20, 0.8), const Offset(0.20, 0.2)],
              [const Offset(0.20, 0.2), const Offset(0.50, 0.58)],
              [const Offset(0.50, 0.58), const Offset(0.80, 0.2)],
              [const Offset(0.80, 0.2), const Offset(0.80, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small m",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.40), const Offset(0.25, 0.80)],
              [
                const Offset(0.25, 0.56),
                const Offset(0.29, 0.46),
                const Offset(0.37, 0.41),
                const Offset(0.45, 0.46),
                const Offset(0.50, 0.56),
                const Offset(0.50, 0.80),
              ],
              [
                const Offset(0.50, 0.56),
                const Offset(0.54, 0.46),
                const Offset(0.62, 0.41),
                const Offset(0.70, 0.46),
                const Offset(0.75, 0.56),
                const Offset(0.75, 0.80),
              ],
            ],
          ),
        ];

      case 'N':
        return [
          TraceLevel(
            letterName: "Big N",
            imagePath: '',
            strokes: [
              [const Offset(0.30, 0.8), const Offset(0.30, 0.2)],
              [const Offset(0.30, 0.2), const Offset(0.70, 0.8)],
              [const Offset(0.70, 0.8), const Offset(0.70, 0.2)],
            ],
          ),
          TraceLevel(
            letterName: "Small n",
            imagePath: '',
            strokes: [
              [const Offset(0.35, 0.40), const Offset(0.35, 0.80)],
              [
                const Offset(0.35, 0.56),
                const Offset(0.39, 0.46),
                const Offset(0.50, 0.41),
                const Offset(0.61, 0.46),
                const Offset(0.65, 0.56),
                const Offset(0.65, 0.80),
              ],
            ],
          ),
        ];

      case 'O':
        return [
          TraceLevel(
            letterName: "Big O",
            imagePath: '',
            strokes: [
              [
                const Offset(0.50, 0.20),
                const Offset(0.40, 0.24),
                const Offset(0.33, 0.35),
                const Offset(0.30, 0.50),
                const Offset(0.33, 0.65),
                const Offset(0.40, 0.76),
                const Offset(0.50, 0.80),
                const Offset(0.60, 0.76),
                const Offset(0.67, 0.65),
                const Offset(0.70, 0.50),
                const Offset(0.67, 0.35),
                const Offset(0.60, 0.24),
                const Offset(0.50, 0.20),
                const Offset(0.40, 0.24),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small o",
            imagePath: '',
            strokes: [
              [
                const Offset(0.50, 0.40),
                const Offset(0.425, 0.43),
                const Offset(0.37, 0.50),
                const Offset(0.35, 0.60),
                const Offset(0.37, 0.70),
                const Offset(0.425, 0.77),
                const Offset(0.50, 0.80),
                const Offset(0.575, 0.77),
                const Offset(0.63, 0.70),
                const Offset(0.65, 0.60),
                const Offset(0.63, 0.50),
                const Offset(0.575, 0.43),
                const Offset(0.50, 0.40),
                const Offset(0.425, 0.43),
              ],
            ],
          ),
        ];

      case 'P':
        return [
          TraceLevel(
            letterName: "Big P",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)],
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.7, 0.35),
                const Offset(0.6, 0.5),
                const Offset(0.3, 0.5),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small p",
            imagePath: '',
            strokes: [
              [const Offset(0.34, 0.28), const Offset(0.34, 0.83)],
              [
                const Offset(0.34, 0.38),
                const Offset(0.42, 0.30),
                const Offset(0.54, 0.28),
                const Offset(0.64, 0.36),
                const Offset(0.67, 0.48),
                const Offset(0.64, 0.60),
                const Offset(0.54, 0.68),
                const Offset(0.42, 0.66),
                const Offset(0.34, 0.58),
              ],
            ],
          ),
        ];

      case 'Q':
        return [
          TraceLevel(
            letterName: "Big Q",
            imagePath: '',
            strokes: [
              [
                const Offset(0.50, 0.20),
                const Offset(0.40, 0.24),
                const Offset(0.33, 0.35),
                const Offset(0.30, 0.50),
                const Offset(0.33, 0.65),
                const Offset(0.40, 0.76),
                const Offset(0.50, 0.80),
                const Offset(0.60, 0.76),
                const Offset(0.67, 0.65),
                const Offset(0.70, 0.50),
                const Offset(0.67, 0.35),
                const Offset(0.60, 0.24),
                const Offset(0.50, 0.20),
                const Offset(0.40, 0.24),
              ], // Circle
              [const Offset(0.56, 0.66), const Offset(0.76, 0.86)],
            ],
          ),
          TraceLevel(
            letterName: "Small q",
            imagePath: '',
            strokes: [
              [
                const Offset(0.66, 0.36),
                const Offset(0.56, 0.29),
                const Offset(0.44, 0.30),
                const Offset(0.35, 0.40),
                const Offset(0.34, 0.54),
                const Offset(0.42, 0.65),
                const Offset(0.54, 0.68),
                const Offset(0.66, 0.62),
              ],
              [const Offset(0.66, 0.28), const Offset(0.66, 0.83)],
            ],
          ),
        ];

      case 'R':
        return [
          TraceLevel(
            letterName: "Big R",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.2), const Offset(0.3, 0.8)], // Line down
              [
                const Offset(0.3, 0.2),
                const Offset(0.6, 0.2),
                const Offset(0.7, 0.35),
                const Offset(0.6, 0.5),
                const Offset(0.3, 0.5),
              ], // Loop
              [const Offset(0.3, 0.5), const Offset(0.7, 0.8)], // Diagonal leg
            ],
          ),
          TraceLevel(
            letterName: "Small r",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.4), const Offset(0.3, 0.8)], // Line down
              [
                const Offset(0.3, 0.55),
                const Offset(0.45, 0.4),
                const Offset(0.6, 0.4),
              ], // Small arc
            ],
          ),
        ];

      case 'S':
        return [
          TraceLevel(
            letterName: "Big S",
            imagePath: '',
            strokes: [
              [
                const Offset(0.68, 0.28),
                const Offset(0.62, 0.22),
                const Offset(0.53, 0.20),
                const Offset(0.44, 0.21),
                const Offset(0.36, 0.26),
                const Offset(0.33, 0.34),
                const Offset(0.37, 0.42),
                const Offset(0.46, 0.48),
                const Offset(0.55, 0.52),
                const Offset(0.64, 0.57),
                const Offset(0.68, 0.65),
                const Offset(0.64, 0.73),
                const Offset(0.56, 0.78),
                const Offset(0.46, 0.80),
                const Offset(0.38, 0.77),
                const Offset(0.32, 0.71),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small s",
            imagePath: '',
            strokes: [
              [
                const Offset(0.635, 0.453),
                const Offset(0.59, 0.413),
                const Offset(0.52, 0.40),
                const Offset(0.455, 0.407),
                const Offset(0.395, 0.44),
                const Offset(0.37, 0.493),
                const Offset(0.40, 0.547),
                const Offset(0.47, 0.587),
                const Offset(0.54, 0.613),
                const Offset(0.605, 0.647),
                const Offset(0.635, 0.70),
                const Offset(0.605, 0.753),
                const Offset(0.545, 0.787),
                const Offset(0.47, 0.80),
                const Offset(0.41, 0.78),
                const Offset(0.365, 0.74),
              ],
            ],
          ),
        ];

      case 'T':
        return [
          TraceLevel(
            letterName: "Big T",
            imagePath: '',
            strokes: [
              [const Offset(0.2, 0.2), const Offset(0.8, 0.2)],
              [const Offset(0.5, 0.2), const Offset(0.5, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small t",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.2), const Offset(0.5, 0.8)],
              [const Offset(0.3, 0.45), const Offset(0.7, 0.45)],
            ],
          ),
        ];

      case 'U':
        return [
          TraceLevel(
            letterName: "Capital U",
            imagePath: '',
            strokes: [
              [
                const Offset(0.3, 0.2),
                const Offset(0.3, 0.6),
                const Offset(0.35, 0.72),
                const Offset(0.5, 0.78),
                const Offset(0.65, 0.72),
                const Offset(0.7, 0.6),
                const Offset(0.7, 0.2),
              ],
            ],
          ),
          TraceLevel(
            letterName: "Small u",
            imagePath: '',
            strokes: [
              [
                const Offset(0.35, 0.4),
                const Offset(0.35, 0.65),
                const Offset(0.4, 0.73),
                const Offset(0.5, 0.76),
                const Offset(0.6, 0.73),
                const Offset(0.65, 0.65),
                const Offset(0.65, 0.4),
              ],
              [const Offset(0.65, 0.4), const Offset(0.65, 0.76)],
            ],
          ),
        ];

      case 'V':
        return [
          TraceLevel(
            letterName: "Capital V",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.2), const Offset(0.5, 0.78)],
              [const Offset(0.5, 0.78), const Offset(0.75, 0.2)],
            ],
          ),
          TraceLevel(
            letterName: "Small v",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.4), const Offset(0.5, 0.76)],
              [const Offset(0.5, 0.76), const Offset(0.7, 0.4)],
            ],
          ),
        ];

      case 'W':
        return [
          TraceLevel(
            letterName: "Capital W",
            imagePath: '',
            strokes: [
              [const Offset(0.15, 0.2), const Offset(0.32, 0.78)],
              [const Offset(0.32, 0.78), const Offset(0.5, 0.35)],
              [const Offset(0.5, 0.35), const Offset(0.68, 0.78)],
              [const Offset(0.68, 0.78), const Offset(0.85, 0.2)],
            ],
          ),
          TraceLevel(
            letterName: "Small w",
            imagePath: '',
            strokes: [
              [const Offset(0.15, 0.4), const Offset(0.32, 0.76)],
              [const Offset(0.32, 0.76), const Offset(0.5, 0.5)],
              [const Offset(0.5, 0.5), const Offset(0.68, 0.76)],
              [const Offset(0.68, 0.76), const Offset(0.85, 0.4)],
            ],
          ),
        ];

      case 'X':
        return [
          TraceLevel(
            letterName: "Big X",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.2), const Offset(0.75, 0.8)],
              [const Offset(0.75, 0.2), const Offset(0.25, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small x",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.45), const Offset(0.7, 0.8)],
              [const Offset(0.7, 0.45), const Offset(0.3, 0.8)],
            ],
          ),
        ];

      case 'Y':
        return [
          TraceLevel(
            letterName: "Big Y",
            imagePath: '',
            strokes: [
              [const Offset(0.25, 0.2), const Offset(0.5, 0.45)],
              [const Offset(0.75, 0.2), const Offset(0.5, 0.45)],
              [const Offset(0.5, 0.45), const Offset(0.5, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small y",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.4), const Offset(0.5, 0.7)],
              [const Offset(0.7, 0.4), const Offset(0.4, 0.9)],
            ],
          ),
        ];

      case 'Z':
        return [
          TraceLevel(
            letterName: "Big Z",
            imagePath: '',
            strokes: [
              [const Offset(0.2, 0.2), const Offset(0.8, 0.2)],
              [const Offset(0.8, 0.2), const Offset(0.2, 0.8)],
              [const Offset(0.2, 0.8), const Offset(0.8, 0.8)],
            ],
          ),
          TraceLevel(
            letterName: "Small z",
            imagePath: '',
            strokes: [
              [const Offset(0.3, 0.45), const Offset(0.7, 0.45)],
              [const Offset(0.7, 0.45), const Offset(0.3, 0.8)],
              [const Offset(0.3, 0.8), const Offset(0.7, 0.8)],
            ],
          ),
        ];

      default:
      // Fallback to Big A if the requested letter is unsupported
        return [
          TraceLevel(
            letterName: "Big A",
            imagePath: '',
            strokes: [
              [const Offset(0.5, 0.2), const Offset(0.2, 0.8)],
              [const Offset(0.5, 0.2), const Offset(0.8, 0.8)],
              [const Offset(0.35, 0.5), const Offset(0.65, 0.5)],
            ],
          ),
        ];
    }
  }
}