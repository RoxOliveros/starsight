import 'package:flutter/material.dart';

import '../business_layer/database_service.dart';
import '../business_layer/screen_time_service.dart';
import 'avatar_picker_dialog.dart';

abstract class _C {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color navy = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color brown = Color(0xFF6F6764);
  static const Color cardYellow = Color(0x80F6CE66);
}

const String _font = 'Fredoka';

class ScreenTimeScreen extends StatefulWidget {
  /// Which child to preselect (the one chosen in the Parent's Area).
  final String? initialChildId;

  const ScreenTimeScreen({super.key, this.initialChildId});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _children = [];
  String _fallbackAvatar = kDefaultAvatarPath;
  int _selectedIndex = 0;

  bool _loading = true;
  bool _saving = false;

  int _savedLimit = DatabaseService.defaultScreenTimeLimitMinutes;
  int _selectedLimit = DatabaseService.defaultScreenTimeLimitMinutes;
  int _usedSeconds = 0;

  String? get _childId =>
      _children.isEmpty ? null : _children[_selectedIndex]['id'] as String;

  String get _childName => _children.isEmpty
      ? ''
      : (_children[_selectedIndex]['nickname'] as String? ?? _childId ?? '');

  bool get _hasChanges => _selectedLimit != _savedLimit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final children = await _db.getChildren();
    final fallback = await AvatarStorage.getSelectedAvatarPath();
    final index = children.indexWhere((c) => c['id'] == widget.initialChildId);

    if (!mounted) return;
    setState(() {
      _children = children;
      _fallbackAvatar = fallback;
      _selectedIndex = index >= 0 ? index : 0;
    });
    await _loadSettingsForSelectedChild();
  }

  Future<void> _loadSettingsForSelectedChild() async {
    final id = _childId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final data = await _db.getScreenTime(id);
    if (!mounted) return;

    // Guard against a stored value that isn't one of the dropdown presets.
    final limit =
        DatabaseService.screenTimeLimitOptions.contains(data.limitMinutes)
        ? data.limitMinutes
        : DatabaseService.defaultScreenTimeLimitMinutes;

    setState(() {
      _savedLimit = limit;
      _selectedLimit = limit;
      _usedSeconds = data.usedSeconds;
      _loading = false;
    });
  }

  void _selectChild(int index) {
    if (index == _selectedIndex || _saving) return;
    setState(() => _selectedIndex = index);
    _loadSettingsForSelectedChild();
  }

  Future<void> _save() async {
    final id = _childId;
    if (id == null) return;

    setState(() => _saving = true);
    final ok = await _db.setScreenTimeLimit(id, _selectedLimit);
    if (!mounted) return;

    if (ok) {
      // Applies immediately if this child is the one currently playing.
      ScreenTimeService.instance.updateLimit(id, _selectedLimit);
    }

    setState(() {
      _saving = false;
      if (ok) _savedLimit = _selectedLimit;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? "Saved! $_childName's daily limit is $_selectedLimit minutes."
              : "Couldn't save. Please try again.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _C.navy,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              'SCREEN TIME',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: _C.orange,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a child, then set how long they can play each day.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: _font, fontSize: 13, color: _C.brown),
          ),
          const SizedBox(height: 24),
          _buildChildPicker(),
          const SizedBox(height: 24),
          if (_children.isNotEmpty) _buildLimitCard(),
        ],
      ),
    );
  }

  Widget _buildChildPicker() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: _C.cardYellow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT CHILD',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _C.navy,
            ),
          ),
          const SizedBox(height: 15),
          if (_children.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                "You haven't added a child yet.",
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 13,
                  color: _C.brown,
                ),
              ),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _children.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final child = _children[i];
                  final selected = i == _selectedIndex;
                  final avatar =
                      (child['avatarPath'] as String?) ?? _fallbackAvatar;
                  final name =
                      (child['nickname'] as String?) ?? child['id'] as String;
                  return GestureDetector(
                    onTap: () => _selectChild(i),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.35),
                            border: Border.all(
                              color: selected ? _C.orange : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  Image.asset(
                                    kDefaultAvatarPath,
                                    fit: BoxFit.cover,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 68,
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: _font,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected ? _C.orange : _C.brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLimitCard() {
    final usedMinutes = _usedSeconds ~/ 60;
    final progress = _savedLimit == 0
        ? 0.0
        : (_usedSeconds / (_savedLimit * 60)).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.orange, width: 1.6),
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'DAILY LIMIT',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _C.orange,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.orange.withValues(alpha: 0.6)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedLimit,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: _C.cream,
                      iconEnabledColor: _C.orange,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _C.navy,
                      ),
                      items: [
                        for (final m in DatabaseService.screenTimeLimitOptions)
                          DropdownMenuItem<int>(
                            value: m,
                            child: Text('$m minutes'),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _selectedLimit = v);
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Today: $usedMinutes of $_savedLimit min used",
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.brown,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: _C.orange.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(_C.orange),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Resets every day at 12:00 AM.',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 12,
                    color: _C.brown.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_hasChanges && !_saving) ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _C.orange.withValues(
                        alpha: 0.35,
                      ),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              fontFamily: _font,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
