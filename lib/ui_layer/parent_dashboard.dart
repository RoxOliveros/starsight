import 'package:StarSight/ui_layer/behavior_reports_screen.dart';
import 'package:flutter/material.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color goldenYellow = Color(0xFFFBD481);
  static const Color warmBrown = Color(0xFF5E463E);
}

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: ColorTheme.warmBrown,
            size: 32,
          ),
          // Pops back to the main child dashboard
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Parent's Area",
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: ColorTheme.orange,
                ),
              ),
              const SizedBox(height: 50),

              // ---> BEHAVIOR REPORTS BUTTON <---
              _buildMenuButton(
                icon: Icons.analytics_rounded,
                title: "Behavior Reports",
                color: ColorTheme.deepNavyBlue,
                textColor: Colors.white,
                onTap: () {
                  // Connects the button to the new Firebase screen!
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BehaviorReportsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ---> DAILY ACTIVITY BUTTON <---
              _buildMenuButton(
                icon: Icons.calendar_today_rounded,
                title: "Daily Activity",
                color: ColorTheme.goldenYellow,
                textColor: ColorTheme.warmBrown,
                onTap: () {
                  print("Soon.");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable button widget for a clean UI
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 6),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 34),
            const SizedBox(width: 20),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
