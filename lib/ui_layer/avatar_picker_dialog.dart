import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui_layer/menu_dialog.dart';

const String kAvatarPrefsKey = 'selected_avatar_path';
const String kDefaultAvatarPath = 'assets/images/avatars/avatar_star.png';

class AvatarStorage {
  static Future<String> getSelectedAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kAvatarPrefsKey) ?? kDefaultAvatarPath;
  }

  static Future<void> setSelectedAvatarPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAvatarPrefsKey, path);
  }
}

const List<String> kAvatarAssetPaths = [
  'assets/images/avatars/avatar_bear.png',
  'assets/images/avatars/avatar_bunny.png',
  'assets/images/avatars/avatar_cat.png',
  'assets/images/avatars/avatar_dog.png',
  'assets/images/avatars/avatar_owl.png',
  'assets/images/avatars/avatar_penguin.png',
  'assets/images/avatars/avatar_star.png',
];

class AvatarPickerDialog extends StatefulWidget {
  final String? selectedAssetPath;
  final List<String> avatarAssetPaths;

  const AvatarPickerDialog({
    super.key,
    this.selectedAssetPath,
    this.avatarAssetPaths = kAvatarAssetPaths,
  });

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedAssetPath;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE9C679),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🏷️ Title row
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Choose Your Avatar",
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ColorTheme.orange,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              height: 2,
              color: Colors.white.withValues(alpha: 0.4),
            ),

            const SizedBox(height: 16),

            // 🐻 Avatar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.avatarAssetPaths.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final path = widget.avatarAssetPaths[index];
                final isSelected = path == _selected;

                return _AvatarTile(
                  assetPath: path,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() => _selected = path);
                  },
                );
              },
            ),

            const SizedBox(height: 18),

            // ✅ Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorTheme.orange,
                  disabledBackgroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Confirm",
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

class _AvatarTile extends StatelessWidget {
  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: const Color(0xFFF4DEB3),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? ColorTheme.orange : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: ColorTheme.orange.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ]
              : null,
        ),
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}