import 'package:flutter/material.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color grey = Color(0xFFB0B0B0); // For locked levels
}

class GenericLevelScreen extends StatelessWidget {
  final String categoryName; // e.g., "Alphabet Forest"
  final int highestUnlockedLevel; // e.g., 2 (Means level 1 & 2 are open)
  final int totalLevels; // e.g., 10
  final Function(int) onLevelTapped; // What happens when they click a level

  const GenericLevelScreen({
    super.key,
    required this.categoryName,
    required this.highestUnlockedLevel,
    required this.totalLevels,
    required this.onLevelTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      appBar: AppBar(
        title: Text(
          categoryName,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            color: ColorTheme.deepNavyBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ColorTheme.deepNavyBlue),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GridView.builder(
          itemCount: totalLevels,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 3 levels per row
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemBuilder: (context, index) {
            final int levelNumber = index + 1;
            final bool isUnlocked = levelNumber <= highestUnlockedLevel;

            return GestureDetector(
              onTap: () {
                if (isUnlocked) {
                  onLevelTapped(levelNumber); // Start the game!
                } else {
                  // Show a cute locked message!
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Win the previous level to unlock this one!",
                      ),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? ColorTheme.orange
                      : ColorTheme.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked
                        ? ColorTheme.deepNavyBlue
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: isUnlocked
                      ? Text(
                          levelNumber.toString(),
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
