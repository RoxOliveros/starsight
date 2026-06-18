import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      print('ForestProgressService: failed to load progress: $e');
      return _defaultUnlockedLevel;
    }
  }

  Stream<int> streamUnlockedLevel() {
    final ref = _docRef;
    if (ref == null) return Stream.value(_defaultUnlockedLevel);

    return ref.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return _defaultUnlockedLevel;
      }
      final data = snapshot.data();
      final unlocked = data?['unlockedLevel'] as int?;
      return unlocked ?? _defaultUnlockedLevel;
    });
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
      print('ForestProgressService: failed to save progress: $e');
      return _defaultUnlockedLevel;
    }
  }

  bool isUnlocked(int level, int unlockedLevel) => level <= unlockedLevel;

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
