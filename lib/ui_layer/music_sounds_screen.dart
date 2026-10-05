import 'package:flutter/material.dart';

abstract class _MusPalette {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color teal = Color(0xFF54BDB8);
  static const Color brown = Color(0xFF6F6764);
  static const Color mutedGrey = Color(0xFFB9B2A9);
  static const Color titleSky = Color(0xFF6FD3E3);
  static const Color titleGold = Color(0xFFFACC58);
  static const Color titleOrange = Color(0xFFEC8A20);
}

abstract class _MusFonts {
  static const String fredoka = 'Fredoka';
}

class MusicSoundsScreen extends StatefulWidget {
  const MusicSoundsScreen({super.key});

  @override
  State<MusicSoundsScreen> createState() => _MusicSoundsScreenState();
}

class _MusicSoundsScreenState extends State<MusicSoundsScreen> {
  // UI only: local state so the controls react, nothing is saved.
  bool _musicOn = true;
  double _musicVolume = 0.7;

  bool _sfxOn = true;
  double _sfxVolume = 0.8;

  bool _voiceOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _MusPalette.cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildRainbowTitle('MUSIC & SOUNDS')),
                    const SizedBox(height: 28),

                    // ── Background music (orange) ──
                    _SoundCard(
                      color: _MusPalette.orange,
                      icon: Icons.music_note_rounded,
                      label: 'Background Music',
                      enabled: _musicOn,
                      onToggle: (v) => setState(() => _musicOn = v),
                      volume: _musicVolume,
                      onVolumeChanged: (v) =>
                          setState(() => _musicVolume = v),
                    ),
                    const SizedBox(height: 20),

                    // ── Sound effects (teal) ──
                    _SoundCard(
                      color: _MusPalette.teal,
                      icon: Icons.graphic_eq_rounded,
                      label: 'Sound Effects',
                      enabled: _sfxOn,
                      onToggle: (v) => setState(() => _sfxOn = v),
                      volume: _sfxVolume,
                      onVolumeChanged: (v) => setState(() => _sfxVolume = v),
                    ),
                    const SizedBox(height: 20),

                    // ── Voice narration (navy, toggle only) ──
                    _SoundCard(
                      color: _MusPalette.deepNavyBlue,
                      icon: Icons.record_voice_over_rounded,
                      label: 'Voice Narration',
                      enabled: _voiceOn,
                      onToggle: (v) => setState(() => _voiceOn = v),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _MusPalette.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // Multicolored title (same style as the other screens)
  Widget _buildRainbowTitle(String text) {
    const palette = [
      _MusPalette.titleSky,
      _MusPalette.titleGold,
      _MusPalette.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = _MusPalette.brown;
      } else {
        color = palette[(letterIndex ~/ 2) % palette.length];
        letterIndex++;
      }
      spans.add(TextSpan(text: char, style: TextStyle(color: color)));
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: _MusFonts.fredoka,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }
}

/// Outlined card with a title row + switch, and an optional volume slider.
class _SoundCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final double? volume; // null = no slider
  final ValueChanged<double>? onVolumeChanged;

  const _SoundCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onToggle,
    this.volume,
    this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? color : _MusPalette.mutedGrey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Column(
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 22, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: _MusFonts.fredoka,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _MusPalette.deepNavyBlue,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: Colors.white,
                  activeTrackColor: color,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: _MusPalette.mutedGrey,
                  trackOutlineColor:
                  WidgetStateProperty.all(Colors.transparent),
                ),
              ],
            ),
          ),

          // Volume slider
          if (volume != null) ...[
            Divider(height: 1, color: color.withValues(alpha: 0.25)),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8, right: 4),
              child: Row(
                children: [
                  Icon(Icons.volume_mute_rounded, size: 20, color: accent),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: accent,
                        inactiveTrackColor: accent.withValues(alpha: 0.2),
                        thumbColor: accent,
                        overlayColor: accent.withValues(alpha: 0.15),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                      ),
                      child: Slider(
                        value: volume!,
                        onChanged: enabled ? onVolumeChanged : null,
                      ),
                    ),
                  ),
                  Icon(Icons.volume_up_rounded, size: 20, color: accent),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(volume! * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: _MusFonts.fredoka,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}