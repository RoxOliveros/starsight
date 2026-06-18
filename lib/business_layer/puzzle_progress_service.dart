import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PuzzleProgressService {
  PuzzleProgressService._();
  static final PuzzleProgressService instance = PuzzleProgressService._();

  // Puzzle Glade has 20 levels
  static const int totalLevels = 20;
  static const int _defaultUnlockedLevel = 1;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('puzzle'); // Saves specifically to 'puzzle'
  }

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
      print('PuzzleProgressService: failed to load progress: $e');
      return _defaultUnlockedLevel;
    }
  }

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
      print('PuzzleProgressService: failed to save progress: $e');
      return _defaultUnlockedLevel;
    }
  }
}
