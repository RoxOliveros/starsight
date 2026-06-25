import 'package:flutter/material.dart';

class GeneratingSummaryCard extends StatelessWidget {
  const GeneratingSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      // The exact same dark background overlay
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          width: screenWidth * 0.85,
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7EB), // ColorTheme.cream
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/characters/doma_writing_on_board.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 20),
              const Text(
                "Analyzing Adventure...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Color(0xFF5F7199),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "StarSight AI is writing the summary.\nPlease wait a moment!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5E463E),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
