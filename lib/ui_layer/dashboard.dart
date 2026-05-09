import 'package:StarSight/ui_layer/puzzle_level_screen.dart';
import 'package:StarSight/ui_layer/town_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'arctic_level.dart';
import 'forest_level.dart';
import 'lagoon_level.dart';
import 'menu_dialog.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color blue = Color(0xFF4C89C3);
  static const Color lightblue = Color(0xFF6FD3E3);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color yelloworange = Color(0xFFFACC58);
  static const Color brown = Color(0xFF6F6764);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
  static const String nunito = 'Nunito';
}

// ══════════════════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  final String nickname;

  const DashboardScreen({super.key, required this.nickname});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0 = play, 1 = film, 2 = list, 3 = archive
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Activity/island cards
  final List<_ActivityCard> _activities = const [
    _ActivityCard(
      title: 'Alphabet Forest',
      subtitle: '...',
      isActive: true,
      imagePath: 'assets/animations/forest.json',
    ),
    _ActivityCard(
      title: 'Town',
      subtitle: '...',
      isActive: false,
      imagePath: 'assets/animations/town.json',
    ),
    _ActivityCard(
      title: 'Artic',
      subtitle: '...',
      isActive: false,
      imagePath: 'assets/animations/arctic.json',
    ),
    _ActivityCard(
      title: 'Lagoon',
      subtitle: '...',
      isActive: false,
      imagePath: 'assets/animations/lagoon.json',
    ),
    _ActivityCard(
      title: 'Puzzle',
      subtitle: '...',
      isActive: false,
      imagePath: 'assets/animations/puzzle.json',
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Full-screen cloud background ──────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    // Left cloud
                    Positioned(
                      left: -60,
                      top: -50,
                      bottom: 0,
                      child: Center(
                        child: Lottie.asset(
                          'assets/animations/white_clouds_mirrored.json',
                          width: 350,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 200),
                        ),
                      ),
                    ),
                    // Center cloud
                    Positioned(
                      left: 0,
                      right: 0,
                      top: -120,
                      bottom: 0,
                      child: Center(
                        child: Lottie.asset(
                          'assets/animations/white_cloud.json',
                          width: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 80),
                        ),
                      ),
                    ),
                    // Right cloud
                    Positioned(
                      right: -70,
                      top: -200,
                      bottom: 0,
                      child: Center(
                        child: Lottie.asset(
                          'assets/animations/white_clouds_mirrored.json',
                          width: 350,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 200),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── All UI on top ─────────────────────────────────────────
            Column(
              children: [
                _TopBar(nickname: widget.nickname),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _MainIslandCard(
                      activities: _activities,
                      floatAnimation: _floatAnimation,
                      selectedTab: _selectedTab,
                      onTabChanged: (i) => setState(() => _selectedTab = i),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ══════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final String nickname;

  const _TopBar({required this.nickname});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Truly centered logo ───────────────────────────────────────
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
              children: [
                TextSpan(
                  text: 'ST',
                  style: TextStyle(color: ColorTheme.lightblue),
                ),
                TextSpan(
                  text: 'AR',
                  style: TextStyle(color: ColorTheme.orange),
                ),
                TextSpan(
                  text: 'SI',
                  style: TextStyle(color: ColorTheme.yellow),
                ),
                TextSpan(
                  text: 'GH',
                  style: TextStyle(color: ColorTheme.lightblue),
                ),
                TextSpan(
                  text: 'T',
                  style: TextStyle(color: ColorTheme.orange),
                ),
              ],
            ),
          ),

          // ── Avatar pinned to the left ─────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: _AvatarBadge(name: nickname),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AVATAR
// ══════════════════════════════════════════════════════════════════════════════
class _AvatarBadge extends StatelessWidget {
  final String name;

  const _AvatarBadge({required this.name});

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ProfileDayDialog(name: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double circleSize = 55;
    const double pillHeight = 22;
    const double pillOverlap = 11;

    return GestureDetector(
      onTap: () => _showProfileDialog(context),
      child: SizedBox(
        width: circleSize,
        height: circleSize + pillHeight - pillOverlap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Circle profile
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ColorTheme.yelloworange, width: 3),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/drafts/avatar.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFFD4C4F0)),
                ),
              ),
            ),

            // Name pill
            Positioned(
              top: circleSize - pillOverlap,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: pillHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: ColorTheme.yelloworange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN ISLAND CARD
// ══════════════════════════════════════════════════════════════════════════════
class _MainIslandCard extends StatelessWidget {
  final List<_ActivityCard> activities;
  final Animation<double> floatAnimation;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _MainIslandCard({
    required this.activities,
    required this.floatAnimation,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final islandHeight = constraints.maxHeight * 0.92;
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: _IslandCarousel(
                    activities: activities,
                    floatAnimation: floatAnimation,
                    height: islandHeight,
                  ),
                ),
                const Spacer(),
              ],
            ),

            // story mode button bottom-right
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: () {}, //TODO: @Tin Navigate to storymode
                child: Lottie.asset(
                  'assets/animations/movie_clapperboard.json',
                  width: 56,
                  height: 56,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ISLAND CAROUSEL
// ══════════════════════════════════════════════════════════════════════════════
class _IslandCarousel extends StatelessWidget {
  final List<_ActivityCard> activities;
  final Animation<double> floatAnimation;
  final double height;

  const _IslandCarousel({
    required this.activities,
    required this.floatAnimation,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return _IslandTile(
            activity: activities[index],
            floatAnimation: floatAnimation,
            size: height,
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ISLAND ISLAND
// ══════════════════════════════════════════════════════════════════════════════
class _IslandTile extends StatelessWidget {
  final _ActivityCard activity;
  final Animation<double> floatAnimation;
  final double size;

  const _IslandTile({
    required this.activity,
    required this.floatAnimation,
    required this.size,
  });

  void _navigate(BuildContext context) {
    switch (activity.title) {
      case 'Alphabet Forest':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ForestLevelScreen()),
        );
        break;
      case 'Town':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TownLevelScreen()),
        );
        break;
      case 'Artic':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArcticLevelScreen()),
        );
        break;
      case 'Lagoon':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LagoonLevelScreen()),
        );
        break;
      case 'Puzzle':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PuzzleLevelScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context),
      child: AnimatedBuilder(
        animation: floatAnimation,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, floatAnimation.value),
          child: child,
        ),
        child: Lottie.asset(
          activity.imagePath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _IslandPlaceholder(large: true),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DATA MODEL
// ══════════════════════════════════════════════════════════════════════════════
class _ActivityCard {
  final String title;
  final String subtitle;
  final bool isActive;
  final String imagePath;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.imagePath,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// PLACEHOLDER (when image asset is missing)
// ══════════════════════════════════════════════════════════════════════════════
class _IslandPlaceholder extends StatelessWidget {
  final bool large;

  const _IslandPlaceholder({required this.large});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: large ? 160 : 60,
      height: large ? 120 : 55,
      decoration: BoxDecoration(
        color: ColorTheme.lightblue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.terrain_rounded,
        color: ColorTheme.deepNavyBlue.withValues(alpha: 0.4),
        size: large ? 48 : 24,
      ),
    );
  }
}
