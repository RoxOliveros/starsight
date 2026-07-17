import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TownProgressService {
  TownProgressService._();
  static final TownProgressService instance = TownProgressService._();

  static const int totalLevels = 9;
  static const int _defaultUnlockedLevel = 1;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('lumi_town');
  }

  // Stream to allow the UI to update automatically when a level is unlocked
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
      final snapshot = await ref.get();
      final current =
          (snapshot.data()?['unlockedLevel'] as int?) ?? _defaultUnlockedLevel;

      final newUnlocked = nextLevel > current ? nextLevel : current;

      await ref.set({'unlockedLevel': newUnlocked}, SetOptions(merge: true));

      return newUnlocked;
    } catch (e) {
      print('TownProgressService: failed to save progress: $e');
      return _defaultUnlockedLevel;
    }
  }
}
