import 'package:flutter/material.dart';

class LightingPromptCard extends StatelessWidget {
  final VoidCallback? onClose;

  const LightingPromptCard({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          width: screenWidth * 0.85,
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7EB),
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),

          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 28.0,
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
                      "Ready for Adventure?",
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
                      "Make sure your room is bright and place the phone straight in front of your face!",
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

              if (onClose != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(
                      0xFF5F7199,
                    ).withValues(alpha: 0.5), // Soft navy blue
                    iconSize: 28,
                    onPressed: onClose,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
