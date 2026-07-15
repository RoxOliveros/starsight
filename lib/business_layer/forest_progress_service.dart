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
    switch (letter.toUpperCase()) {
      case 'A':
      case 'B':
      case 'C':
        return 1;

      case 'D':
      case 'E':
      case 'F':
        return 3;

      case 'G':
      case 'H':
      case 'I':
        return 5;

      case 'J':
      case 'K':
      case 'L':
        return 7;

      case 'M':
      case 'N':
      case 'O':
        return 9;

      case 'P':
      case 'Q':
      case 'R':
        return 11;

      case 'S':
      case 'T':
      case 'U':
        return 13;

      case 'V':
      case 'W':
      case 'X':
        return 15;

      case 'Y':
      case 'Z':
        return 17;

      default:
        return null;
    }
  }
}
