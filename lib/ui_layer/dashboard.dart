import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  const DashboardScreen({super.key});

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
      title: 'Forest Camp',
      subtitle: 'Explore the woods',
      isActive: true,
      imagePath: 'assets/images/camp_day.png',
    ),
    _ActivityCard(
      title: 'Night Camp',
      subtitle: 'Stargazing time',
      isActive: false,
      imagePath: 'assets/images/camp_night.png',
    ),
    _ActivityCard(
      title: 'Menu - Night',
      subtitle: 'Dinner adventure',
      isActive: false,
      imagePath: 'assets/images/menu_night.png',
    ),
    _ActivityCard(
      title: 'Menu - Day',
      subtitle: 'Breakfast fun',
      isActive: false,
      imagePath: 'assets/images/menu_day.png',
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
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            _TopBar(),

            const SizedBox(height: 12),

            // ── Main card with island carousel ────────────────────────────
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

            const SizedBox(height: 16),
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
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ColorTheme.yelloworange.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorTheme.yelloworange, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: ColorTheme.deepNavyBlue,
                  size: 28,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Logo
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
              children: [
                TextSpan(
                  text: 'STAR',
                  style: TextStyle(color: ColorTheme.orange),
                ),
                TextSpan(
                  text: 'S',
                  style: TextStyle(color: ColorTheme.deepNavyBlue),
                ),
                TextSpan(
                  text: 'I',
                  style: TextStyle(color: ColorTheme.lightblue),
                ),
                TextSpan(
                  text: 'G',
                  style: TextStyle(color: ColorTheme.yellow),
                ),
                TextSpan(
                  text: 'H',
                  style: TextStyle(color: ColorTheme.deepNavyBlue),
                ),
                TextSpan(
                  text: 'T',
                  style: TextStyle(color: ColorTheme.orange),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Cloud + Star decorations
          Stack(
            clipBehavior: Clip.none,
            children: [
              Image.asset(
                'assets/images/cloud.png',
                width: 60,
                height: 36,
                errorBuilder: (_, __, ___) => const SizedBox(width: 60, height: 36),
              ),
              Positioned(
                top: -10,
                right: -8,
                child: Image.asset(
                  'assets/images/night_star.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ColorTheme.yelloworange.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ColorTheme.yelloworange.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── Island carousel ────────────────────────────────────────────
          Expanded(
            child: _IslandCarousel(
              activities: activities,
              floatAnimation: floatAnimation,
            ),
          ),

          const SizedBox(height: 16),

          // ── Bottom tab bar ─────────────────────────────────────────────
          _BottomTabBar(
            selectedIndex: selectedTab,
            onChanged: onTabChanged,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ISLAND CAROUSEL
// ══════════════════════════════════════════════════════════════════════════════
class _IslandCarousel extends StatelessWidget {
  final List<_ActivityCard> activities;
  final Animation<double> floatAnimation;

  const _IslandCarousel({
    required this.activities,
    required this.floatAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 12),

            // ── Featured (large) island ──────────────────────────────────
            _FeaturedIsland(
              activity: activities.first,
              floatAnimation: floatAnimation,
              width: width * 0.42,
              height: constraints.maxHeight,
            ),

            const SizedBox(width: 10),

            // ── Side islands ─────────────────────────────────────────────
            Expanded(
              child: SizedBox(
                height: constraints.maxHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: activities
                            .skip(1)
                            .map(
                              (a) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _SmallIsland(
                                activity: a,
                                floatAnimation: floatAnimation,
                              ),
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURED ISLAND (large left card)
// ══════════════════════════════════════════════════════════════════════════════
class _FeaturedIsland extends StatelessWidget {
  final _ActivityCard activity;
  final Animation<double> floatAnimation;
  final double width;
  final double height;

  const _FeaturedIsland({
    required this.activity,
    required this.floatAnimation,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ColorTheme.lightblue.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ColorTheme.lightblue.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Sky gradient background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFD6EFFF),
                      Color(0xFFF0F8FF),
                    ],
                  ),
                ),
              ),
            ),

            // Cloud top-left
            Positioned(
              top: 10,
              left: 8,
              child: Image.asset(
                'assets/images/cloud.png',
                width: 55,
                height: 30,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

            // Star top-right
            Positioned(
              top: 8,
              right: 12,
              child: Image.asset(
                'assets/images/night_star.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

            // Floating island image
            Center(
              child: AnimatedBuilder(
                animation: floatAnimation,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, floatAnimation.value),
                  child: child,
                ),
                child: Image.asset(
                  activity.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _IslandPlaceholder(large: true),
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
// SMALL ISLAND CARD
// ══════════════════════════════════════════════════════════════════════════════
class _SmallIsland extends StatelessWidget {
  final _ActivityCard activity;
  final Animation<double> floatAnimation;

  const _SmallIsland({
    required this.activity,
    required this.floatAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ColorTheme.deepNavyBlue.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Soft sky gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE8F4FF),
                      Color(0xFFF8F5FF),
                    ],
                  ),
                ),
              ),
            ),

            // Island image
            Center(
              child: AnimatedBuilder(
                animation: floatAnimation,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, floatAnimation.value * 0.6),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    activity.imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _IslandPlaceholder(large: false),
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
// BOTTOM TAB BAR
// ══════════════════════════════════════════════════════════════════════════════
class _BottomTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _BottomTabBar({
    required this.selectedIndex,
    required this.onChanged,
  });

  static const _icons = [
    Icons.play_arrow_rounded,
    Icons.movie_filter_outlined,
    Icons.list_alt_rounded,
    Icons.archive_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: ColorTheme.yelloworange.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: ColorTheme.yelloworange.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_icons.length, (i) {
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? ColorTheme.yelloworange
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                _icons[i],
                size: 22,
                color: isSelected ? Colors.white : ColorTheme.brown,
              ),
            ),
          );
        }),
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