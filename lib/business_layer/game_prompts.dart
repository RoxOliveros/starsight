class GamePromptConfig {
  final String activityName;
  final String skillFocus;
  final String educatorGuidance;

  const GamePromptConfig({
    required this.activityName,
    required this.skillFocus,
    required this.educatorGuidance,
  });
}

class GamePrompts {
  static const Map<String, GamePromptConfig> registry = {
    // ── Alphabet Forest (Reading) ──
    'forest_woodpecker': GamePromptConfig(
      activityName: 'Woodpecker Letter Listen',
      skillFocus: 'Phonological Awareness & Auditory Discrimination (A, B, C)',
      educatorGuidance:
          'Highlight how the child listened to spoken letter sounds, matched them to visual rungs on the tree, and maintained patience.',
    ),
    'forest_butterfly_garden': GamePromptConfig(
      activityName: 'Butterfly Flower Garden',
      skillFocus: 'Visual Scanning & Letter Identification (G, H, I)',
      educatorGuidance:
          'Emphasize visual scanning across the garden, selective attention, and delight when watching flowers bloom.',
    ),
    'forest_butterfly_match': GamePromptConfig(
      activityName: 'Butterfly Letter Match',
      skillFocus: 'Uppercase to Lowercase Correspondence (J, K, L)',
      educatorGuidance:
          'Focus on fine motor drag-and-drop coordination and persistence pairing uppercase flowers with lowercase butterflies.',
    ),
    'forest_mushroom': GamePromptConfig(
      activityName: 'Mushroom Hide-and-Seek',
      skillFocus:
          'Letter Case Discrimination & Cluttered Visual Search (M, N, O)',
      educatorGuidance:
          'Note the child\'s grasp of "Big" vs "Small" letters and their curiosity discovering hidden creatures.',
    ),

    // ── Puzzle Glade (Logic) ──
    'puzzle_star_sort': GamePromptConfig(
      activityName: 'Star Color Sort',
      skillFocus: 'Color Categorization & Sorting',
      educatorGuidance:
          'Highlight intentional color matching into jars and fine motor drag precision.',
    ),

    'puzzle_pattern_match': GamePromptConfig(
      activityName: 'Star Pattern Match',
      skillFocus: 'Visual Pattern Recognition & Sequencing',
      educatorGuidance:
          'Highlight the child’s ability to recognize repeating visual patterns and their problem-solving focus when predicting the next color in the sequence.',
    ),
  };

  static GamePromptConfig getConfig(String gameId) {
    return registry[gameId] ??
        const GamePromptConfig(
          activityName: 'Learning Activity',
          skillFocus: 'General Cognitive & Motor Development',
          educatorGuidance:
              'Write a warm summary celebrating engagement, curiosity, and learning persistence.',
        );
  }
}
