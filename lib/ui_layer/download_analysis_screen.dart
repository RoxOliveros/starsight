import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'avatar_picker_dialog.dart'; // for kDefaultAvatarPath
import '../business_layer/analysis_pdf_service.dart';

abstract class _DlPalette {
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

abstract class _DlFonts {
  static const String fredoka = 'Fredoka';
}

class _DlSubject {
  final String id;
  final String name;
  final String lottie;
  final IconData fallbackIcon;
  final Color color; // outline / check color
  final Color softBg; // background when selected

  const _DlSubject({
    required this.id,
    required this.name,
    required this.lottie,
    required this.fallbackIcon,
    required this.color,
    required this.softBg,
  });
}

class DownloadAnalysisScreen extends StatefulWidget {
  /// Firestore document ID of the child (never changes), plus the display
  /// name and avatar of the child the report is for.
  final String childId;
  final String childName;
  final String avatarPath;

  const DownloadAnalysisScreen({
    super.key,
    required this.childId,
    this.childName = 'Child Name',
    this.avatarPath = kDefaultAvatarPath,
  });

  @override
  State<DownloadAnalysisScreen> createState() => _DownloadAnalysisScreenState();
}

class _DownloadAnalysisScreenState extends State<DownloadAnalysisScreen> {
  static const List<_DlSubject> _subjects = [
    _DlSubject(
      id: 'alphabet_forest',
      name: 'Alphabet Forest',
      lottie: 'assets/animations/forest.json',
      fallbackIcon: Icons.abc_rounded,
      color: _DlPalette.titleGold,
      softBg: Color(0xFFFCEFD1),
    ),
    _DlSubject(
      id: 'lumi_town',
      name: 'Lumitown',
      lottie: 'assets/animations/town.json',
      fallbackIcon: Icons.science_rounded,
      color: _DlPalette.teal,
      softBg: Color(0xFFD9F1F5),
    ),
    _DlSubject(
      id: 'arctic_numberland',
      name: 'Arctic Numberland',
      lottie: 'assets/animations/arctic.json',
      fallbackIcon: Icons.pin_rounded,
      color: _DlPalette.orange,
      softBg: Color(0xFFFBE1CB),
    ),
    _DlSubject(
      id: 'discovery_lagoon',
      name: 'Discovery Lagoon',
      lottie: 'assets/animations/lagoon.json',
      fallbackIcon: Icons.favorite_rounded,
      color: _DlPalette.titleGold,
      softBg: Color(0xFFFCEFD1),
    ),
    _DlSubject(
      id: 'puzzle_glade',
      name: 'Puzzle Glade',
      lottie: 'assets/animations/puzzle.json',
      fallbackIcon: Icons.extension_rounded,
      color: _DlPalette.teal,
      softBg: Color(0xFFD9F1F5),
    ),
  ];

  final Set<String> _selected = {};
  bool _isGenerating = false;

  bool get _allSelected => _selected.length == _subjects.length;

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_subjects.map((s) => s.id));
      }
    });
  }

  Future<void> _showPromptCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    String buttonLabel = 'GOT IT',
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: _DlPalette.cream,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(icon, size: 34, color: color),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _DlFonts.fredoka,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: _DlPalette.brown,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontFamily: _DlFonts.fredoka,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lets the parent choose: save a copy on the device, or share it.
  /// Returns 'saved', 'shared', or null if the parent cancelled.
  Future<String?> _deliver(Uint8List bytes) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _DlPalette.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'YOUR PDF IS READY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _DlFonts.fredoka,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _DlPalette.orange,
                ),
              ),
              const SizedBox(height: 14),
              _buildChoiceTile(
                icon: Icons.save_alt_rounded,
                color: _DlPalette.teal,
                title: 'SAVE TO DEVICE',
                subtitle: 'Choose a folder on this phone or tablet',
                onTap: () => Navigator.pop(sheetContext, 'save'),
              ),
              const SizedBox(height: 10),
              _buildChoiceTile(
                icon: Icons.share_rounded,
                color: _DlPalette.orange,
                title: 'SHARE OR PRINT',
                subtitle: 'Email, Drive, messages, print and more',
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return null;

    final filename = AnalysisPdfService.filenameFor(widget.childName);
    if (choice == 'save') {
      final saved = await AnalysisPdfService.saveToDevice(bytes, filename);
      return saved ? 'saved' : null; // null = cancelled
    }
    await AnalysisPdfService.share(bytes, filename);
    return 'shared';
  }

  Widget _buildChoiceTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 1.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: _DlFonts.fredoka,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _DlPalette.deepNavyBlue,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _DlPalette.brown,
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

  Future<void> _download() async {
    if (_isGenerating || _selected.isEmpty) return;
    setState(() => _isGenerating = true);

    try {
      // Keep the on-screen order of the subjects.
      final chosen = {
        for (final s in _subjects)
          if (_selected.contains(s.id)) s.id: s.name,
      };

      final result = await AnalysisPdfService.build(
        childId: widget.childId,
        childName: widget.childName,
        subjects: chosen,
      );
      if (!mounted) return;

      final bytes = result.bytes;
      if (bytes == null) {
        await _showPromptCard(
          icon: Icons.assignment_outlined,
          color: _DlPalette.teal,
          title: 'NO REPORTS YET',
          message:
              'There is nothing to download for your selected subjects yet. '
              'Play at least one level in any of the selected subjects first, '
              'then come back and try again.',
        );
        return;
      }

      final outcome = await _deliver(bytes);
      if (!mounted || outcome == null) return;

      final missing = result.missingSubjects;
      final leftOut = missing.isEmpty
          ? ''
          : 'Left out (no report yet): ${missing.join(', ')}.';

      if (outcome == 'saved') {
        await _showPromptCard(
          icon: Icons.check_circle_rounded,
          color: _DlPalette.teal,
          title: 'SAVED!',
          message: leftOut.isEmpty
              ? 'Your report was saved to your device.'
              : 'Your report was saved to your device.\n\n$leftOut',
        );
      } else if (leftOut.isNotEmpty) {
        await _showPromptCard(
          icon: Icons.info_outline_rounded,
          color: _DlPalette.orange,
          title: 'HEADS UP',
          message: leftOut,
        );
      }
    } catch (e) {
      print('Error creating PDF: $e');
      await _showPromptCard(
        icon: Icons.error_outline_rounded,
        color: _DlPalette.orange,
        title: 'OOPS!',
        message: 'We could not create the PDF. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DlPalette.cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildRainbowTitle('DOWNLOAD ANALYSIS')),
                    const SizedBox(height: 8),
                    const Text(
                      'Save your child\'s report as a PDF to keep or share.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _DlPalette.brown,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Child card ──
                    _buildChildCard(),
                    const SizedBox(height: 28),

                    // ── Subjects header + select all ──
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'CHOOSE CATEGORY',
                            style: TextStyle(
                              fontFamily: _DlFonts.fredoka,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _DlPalette.orange,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _allSelected
                                  ? _DlPalette.teal
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _DlPalette.teal,
                                width: 1.6,
                              ),
                            ),
                            child: Text(
                              _allSelected ? 'CLEAR' : 'SELECT ALL',
                              style: TextStyle(
                                fontFamily: _DlFonts.fredoka,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: _allSelected
                                    ? Colors.white
                                    : _DlPalette.teal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Subject cards ──
                    for (final s in _subjects) ...[
                      _buildSubjectCard(s),
                      const SizedBox(height: 14),
                    ],

                    const SizedBox(height: 6),
                    _buildInfoNote(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
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
            color: _DlPalette.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // Multicolored title (same style as the other screens)
  Widget _buildRainbowTitle(String text) {
    const palette = [
      _DlPalette.titleSky,
      _DlPalette.titleGold,
      _DlPalette.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = _DlPalette.brown;
      } else {
        color = palette[(letterIndex ~/ 2) % palette.length];
        letterIndex++;
      }
      spans.add(
        TextSpan(
          text: char,
          style: TextStyle(color: color),
        ),
      );
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: _DlFonts.fredoka,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildChildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _DlPalette.orange, width: 1.6),
      ),
      child: Row(
        children: [
          // Child avatar
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _DlPalette.orange, width: 3),
            ),
            child: ClipOval(
              child: Image.asset(
                widget.avatarPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.face_rounded,
                  size: 26,
                  color: _DlPalette.orange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REPORT FOR',
                  style: TextStyle(
                    fontFamily: _DlFonts.fredoka,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _DlPalette.mutedGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.childName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: _DlFonts.fredoka,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _DlPalette.deepNavyBlue,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.picture_as_pdf_rounded,
            size: 26,
            color: _DlPalette.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(_DlSubject s) {
    final selected = _selected.contains(s.id);

    return GestureDetector(
      onTap: () => _toggle(s.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? s.softBg : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? s.color
                : _DlPalette.brown.withValues(alpha: 0.15),
            width: 1.8,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Lottie.asset(
                s.lottie,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    Icon(s.fallbackIcon, size: 28, color: s.color),
              ),
            ),
            const SizedBox(width: 12),
            // Title only (description removed)
            Expanded(
              child: Text(
                s.name,
                style: const TextStyle(
                  fontFamily: _DlFonts.fredoka,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _DlPalette.deepNavyBlue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Round check indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? s.color : Colors.transparent,
                border: Border.all(
                  color: selected ? s.color : _DlPalette.mutedGrey,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _DlPalette.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: _DlPalette.teal),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The PDF includes the selected subjects\' insights. It is a '
              'helpful guide based on gameplay, not a formal assessment.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: _DlPalette.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final enabled = _selected.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: _DlPalette.cream,
        border: Border(
          top: BorderSide(
            color: _DlPalette.brown.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          // While generating, keep the button looking active but inert.
          onPressed: enabled ? (_isGenerating ? () {} : _download) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _DlPalette.orange,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _DlPalette.mutedGrey.withValues(
              alpha: 0.5,
            ),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          icon: _isGenerating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 22),
          label: Text(
            _isGenerating
                ? 'CREATING PDF...'
                : enabled
                ? 'DOWNLOAD PDF  (${_selected.length})'
                : 'SELECT A SUBJECT',
            style: const TextStyle(
              fontFamily: _DlFonts.fredoka,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
