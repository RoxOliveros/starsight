import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles reading and writing the player's Alphabet Forest level progress
/// to Cloud Firestore.
///
/// Data shape (one document per user):
///   users/{uid}/progress/forest
///     { "unlockedLevel": 1 }
///
/// `unlockedLevel` means "the highest level number the player is currently
/// allowed to play". A fresh player starts at 1 (only level 1 playable).
/// Completing level N unlocks level N+1, so unlockedLevel becomes N+1.
class ForestProgressService {
  ForestProgressService._();
  static final ForestProgressService instance = ForestProgressService._();

  static const int totalLevels = 24;
  static const int _defaultUnlockedLevel = 1;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('forest');
  }

  /// Fetches the highest unlocked level for the current user.
  /// Returns 1 if there's no user signed in, or no progress doc exists yet
  /// (i.e. brand new player).
  Future<int> getUnlockedLevel() async {
    final ref = _docRef;
    if (ref == null) return _defaultUnlockedLevel;

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        return _defaultUnlockedLevel;
      }
      final data = snapshot.data();
      final unlocked = data?['unlockedLevel'] as int?;
      return unlocked ?? _defaultUnlockedLevel;
    } catch (e) {
      // If Firestore is unreachable, fail safe to "only level 1 unlocked"
      // rather than crashing the level-select screen.
      print('ForestProgressService: failed to load progress: $e');
      return _defaultUnlockedLevel;
    }
  }

  /// Call this when the player finishes a level (e.g. from the
  /// win/results screen). If [completedLevel] is the current frontier
  /// (or beyond it), this unlocks the next level and persists it.
  /// Returns the new unlockedLevel value.
  Future<int> markLevelComplete(int completedLevel) async {
    final ref = _docRef;
    if (ref == null) return _defaultUnlockedLevel;

    final nextLevel = (completedLevel + 1).clamp(1, totalLevels);

    try {
      final current = await getUnlockedLevel();
      final newUnlocked = nextLevel > current ? nextLevel : current;

      await ref.set({'unlockedLevel': newUnlocked}, SetOptions(merge: true));

      return newUnlocked;
    } catch (e) {
      print('ForestProgressService: failed to save progress: $e');
      return _defaultUnlockedLevel;
    }
  }

  /// Convenience check used by the UI: is [level] currently playable?
  bool isUnlocked(int level, int unlockedLevel) => level <= unlockedLevel;

  /// Converts an alphabet-forest letter (A-N) to its level-select number,
  /// following the grid order used in ForestLevelScreen: A=1, B=2 ... G=7,
  /// H=9, I=10 ... N=15 (level 8 and 16 are reserved for the Match/Fall
  /// boss rounds, so the numbering skips over them after G and N).
  ///
  /// Returns null for letters that aren't mapped to a level yet (O-Z),
  /// since those aren't wired into the unlock system.
  static int? levelNumberForLetter(String letter) {
    final upper = letter.toUpperCase();
    const order = [
      'A', 'B', 'C', 'D', 'E', 'F', 'G', // levels 1-7
      'H', 'I', 'J', 'K', 'L', 'M', 'N', // levels 9-15
    ];
    final index = order.indexOf(upper);
    if (index == -1) return null;
    // A-G map directly to 1-7. H-N need +2 to skip over level 8 (Match).
    return index < 7 ? index + 1 : index + 2;
  }
}
