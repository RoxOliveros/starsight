import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/ui_layer/puzzle_glade/puzzle_level.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'arctic_numberland/arctic_level.dart';
import 'alphabet_forest_ui/forest_level.dart';
import 'avatar_picker_dialog.dart';
import 'discovery_lagoon/lagoon_level.dart';
import 'lumi_town/town_level.dart';
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

  bool _animationsReady = false;

  final GlobalKey<_AvatarBadgeState> _avatarBadgeKey = GlobalKey();

  // Activity/island cards
  final List<_ActivityCard> _activities = const [
    _ActivityCard(
      title: 'Alphabet Forest',
      subtitle: '...',
      isActive: true,
      imagePath: 'assets/animations/forest.json',
    ),
    _ActivityCard(
      title: 'Lumi Town',
      subtitle: '...',
      isActive: false,
      imagePath: 'assets/animations/town.json',
    ),
    _ActivityCard(
      title: 'Artic Numberland',
      subtitle: '...',
      isActive: false,
      imagePath: 'assets/animations/arctic.json',
    ),
    _ActivityCard(
      title: 'Discovery Lagoon',
      subtitle: '...',
      isActive: false,
      imagePath: 'assets/animations/lagoon.json',
    ),
    _ActivityCard(
      title: 'Puzzle Glade',
      subtitle: '...',
      isActive: false,
      imagePath: 'assets/animations/puzzle.json',
    ),
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _loadAnimations();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimations() async {
    await Future.wait([
      AssetLottie('assets/animations/white_clouds_mirrored.json').load(),
      AssetLottie('assets/animations/white_cloud.json').load(),
      AssetLottie('assets/animations/forest.json').load(),
      AssetLottie('assets/animations/town.json').load(),
      AssetLottie('assets/animations/arctic.json').load(),
      AssetLottie('assets/animations/lagoon.json').load(),
      AssetLottie('assets/animations/puzzle.json').load(),
    ]);
    if (mounted) {
      setState(() => _animationsReady = true);
      _floatController.repeat(reverse: true); // start float AFTER ready
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      onDrawerChanged: (isOpen) {
        if (!isOpen) _avatarBadgeKey.currentState?.refresh();
      },
      backgroundColor: ColorTheme.cream,
      drawer: Drawer(
        backgroundColor: const Color(0xFFE9C679),
        child: ProfileDayDialog(name: widget.nickname),
      ),
      body: SafeArea(
        child: _animationsReady
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Full-screen cloud background ──────────────────────────
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Left cloud
                          Positioned(
                            left: -60,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Lottie.asset(
                                'assets/animations/white_clouds_mirrored.json',
                                width: 550,
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
                            top: -150,
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
                            right: -200,
                            top: -50,
                            bottom: 0,
                            child: Center(
                              child: Lottie.asset(
                                'assets/animations/white_clouds_mirrored.json',
                                width: 550,
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
                      _TopBar(nickname: widget.nickname, avatarBadgeKey: _avatarBadgeKey),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _MainIslandCard(
                            activities: _activities,
                            floatAnimation: _floatAnimation,
                            selectedTab: _selectedTab,
                            onTabChanged: (i) =>
                                setState(() => _selectedTab = i),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Center(
                child: Image.asset(
                  'assets/images/characters/doma_writing_on_board.png',
                  width: 150,
                ),
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
  final GlobalKey<_AvatarBadgeState> avatarBadgeKey;

  const _TopBar({required this.nickname, required this.avatarBadgeKey});

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
            child: _AvatarBadge(key: avatarBadgeKey, name: nickname),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AVATAR
// ══════════════════════════════════════════════════════════════════════════════
class _AvatarBadge extends StatefulWidget {
  final String name;
  const _AvatarBadge({super.key, required this.name});
  @override
  State<_AvatarBadge> createState() => _AvatarBadgeState();
}

class _AvatarBadgeState extends State<_AvatarBadge> {
  String _avatarPath = kDefaultAvatarPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await AvatarStorage.getSelectedAvatarPath();
    if (mounted) setState(() => _avatarPath = path);
  }

  void refresh() => _load();

  void _showProfileDialog(BuildContext context) {
    Scaffold.of(context).openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    const double circleSize = 55;
    const double pillHeight = 22;
    const double pillOverlap = 7;

    return Builder(
      builder: (context) {
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
                    border: Border.all(
                      color: ColorTheme.yelloworange,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(_avatarPath,
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
                        widget.name,
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
      },
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
            // Positioned(
            //   right: 5,
            //   bottom: 5,
            //   child: GestureDetector(
            //     onTap: () {}, //TODO: @Tin Navigate to storymode
            //     child: Lottie.asset(
            //       'assets/animations/movie_clapperboard.json',
            //       width: 60,
            //       height: 60,
            //       errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            //     ),
            //   ),
            // ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ISLAND CAROUSEL
// ══════════════════════════════════════════════════════════════════════════════

class _IslandCarousel extends StatefulWidget {
  final List<_ActivityCard> activities;
  final Animation<double> floatAnimation;
  final double height;

  const _IslandCarousel({
    required this.activities,
    required this.floatAnimation,
    required this.height,
  });

  @override
  State<_IslandCarousel> createState() => _IslandCarouselState();
}

class _IslandCarouselState extends State<_IslandCarousel> {
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      final percent = currentScroll / maxScroll;

      final newIndex = (percent * (widget.activities.length - 1)).round();

      if (newIndex != _currentIndex) {
        setState(() {
          _currentIndex = newIndex;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.activities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _IslandTile(
                activity: widget.activities[index],
                floatAnimation: widget.floatAnimation,
                size: widget.height,
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.activities.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),

              width: _currentIndex == index ? 18 : 10,
              height: 10,

              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? ColorTheme.orange
                    : ColorTheme.yelloworange.withValues(alpha: 0.4),

                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ISLAND ISLAND
// ══════════════════════════════════════════════════════════════════════════════

class _IslandTile extends StatefulWidget {
  final _ActivityCard activity;
  final Animation<double> floatAnimation;
  final double size;
  final Duration glowDuration;

  const _IslandTile({
    required this.activity,
    required this.floatAnimation,
    required this.size,
    // ignore: unused_element_parameter
    this.glowDuration = const Duration(milliseconds: 300),
  });

  @override
  State<_IslandTile> createState() => _IslandTileState();
}

class _IslandTileState extends State<_IslandTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;
  bool _glowing = false;

  void _navigate(BuildContext context) {
    final navigator = Navigator.of(context);
    setState(() => _glowing = true);
    _tapController
        .forward()
        .then((_) => Future.delayed(widget.glowDuration))
        .then((_) => _tapController.reverse())
        .then((_) {
          if (!mounted) return;
          setState(() => _glowing = false);
          switch (widget.activity.title) {
            case 'Alphabet Forest':
              navigator.push(
                MaterialPageRoute(builder: (_) => const ForestLevelScreen()),
              );
              break;
            case 'Lumi Town':
              navigator.push(
                MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
              );
              break;
            case 'Artic Numberland':
              navigator.push(
                MaterialPageRoute(builder: (_) => const ArcticLevelScreen()),
              );
              break;
            case 'Discovery Lagoon':
              navigator.push(
                MaterialPageRoute(builder: (_) => const LagoonLevelScreen()),
              );
              break;
            case 'Puzzle Glade':
              navigator.push(
                MaterialPageRoute(builder: (_) => const PuzzleLevelScreen()),
              );
              break;
          }
        });
  }

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context),
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.floatAnimation, _scaleAnimation]),
        builder: (_, child) => Transform.translate(
          offset: Offset(0, widget.floatAnimation.value),
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: _glowing
                    ? [
                        BoxShadow(
                          color: ColorTheme.yellow.withValues(alpha: 0.8),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Lottie.asset(
                widget.activity.imagePath,
                width: widget.size,
                height: widget.size * 0.85,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _IslandPlaceholder(large: true),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -25),
              child: Text(
                widget.activity.title,
                style: const TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ColorTheme.deepNavyBlue,
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
