import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LagoonProgressService {
  String? activeChildId;
  LagoonProgressService._();
  static final LagoonProgressService instance = LagoonProgressService._();

  static const int totalLevels = 20;
  static const int _defaultUnlockedLevel = 5;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || activeChildId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('children')
        .doc(activeChildId)
        .collection('progress')
        .doc('lagoon');
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

  /// Levels the active child has played in the current playthrough.
  Future<Set<int>> getPlayedLevels() async {
    final ref = _docRef;
    if (ref == null) return {};
    try {
      final snapshot = await ref.get();
      return ((snapshot.data()?['playedLevels'] as List?) ?? const [])
          .whereType<int>()
          .toSet();
    } catch (e) {
      print('LagoonProgressService: failed to load played levels: $e');
      return {};
    }
  }

  Future<int> markLevelComplete(int completedLevel) async {
    final ref = _docRef;
    if (ref == null) return _defaultUnlockedLevel;

    final nextLevel = (completedLevel + 1).clamp(1, totalLevels);

    try {
      return await FirebaseFirestore.instance.runTransaction<int>((txn) async {
        final snapshot = await txn.get(ref);
        final data = snapshot.data();
        final current =
            (data?['unlockedLevel'] as int?) ?? _defaultUnlockedLevel;
        final newUnlocked = nextLevel > current ? nextLevel : current;

        // Levels played in the current playthrough (drives the star counter).
        // Once every level is played and one is replayed, a new playthrough
        // starts.
        final played = ((data?['playedLevels'] as List?) ?? const [])
            .whereType<int>()
            .toSet();
        if (played.length >= totalLevels && played.contains(completedLevel)) {
          played
            ..clear()
            ..add(completedLevel);
        } else {
          played.add(completedLevel);
        }

        txn.set(ref, {
          'unlockedLevel': newUnlocked,
          'playedLevels': played.toList()..sort(),
        }, SetOptions(merge: true));
        return newUnlocked;
      });
    } catch (e) {
      print('LagoonProgressService: failed to save progress: $e');
      return _defaultUnlockedLevel;
    }
  }
}
