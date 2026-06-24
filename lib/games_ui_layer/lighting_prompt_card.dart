import 'package:flutter/material.dart';

class LightingPromptCard extends StatelessWidget {
  const LightingPromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Getting screen width to ensure responsiveness
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Container(
        // Keeps the card from becoming too wide on large screens
        width: screenWidth * 0.85,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withValues(
            alpha: 0.95,
          ), // Slight transparency to blend with the game background
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: Colors.amber.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Hugs content tightly
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Colors.amber.shade800,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Ready for Adventure?",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Make sure your room is bright and hold the phone straight in front of your face!",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber.shade800,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
