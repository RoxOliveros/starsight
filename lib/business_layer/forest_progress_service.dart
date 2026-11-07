import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForestProgressService {
  ForestProgressService._();
  static final ForestProgressService instance = ForestProgressService._();

  // --- Add a variable to track which child is currently playing ---
  String? activeChildId;

  static const int totalLevels = 30;
  static const int _defaultUnlockedLevel = 5;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // --- Make sure we have BOTH a parent ID and a child ID ---
    if (uid == null || activeChildId == null) {
      print('ForestProgressService: Missing UID or activeChildId');
      return null;
    }

    // --- UPDATED: Route the path through the children collection ---
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('children')
        .doc(activeChildId)
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
      return await FirebaseFirestore.instance.runTransaction<int>((txn) async {
        final snapshot = await txn.get(ref);
        final data = snapshot.data();
        final current =
            (data?['unlockedLevel'] as int?) ?? _defaultUnlockedLevel;
        final newUnlocked = nextLevel > current ? nextLevel : current;

        // Levels played in the current playthrough (drives the honey counter).
        // Same rule as ForestDatabaseService: once the forest is full (25) and
        // a level is replayed, a new playthrough starts.
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
      print('ForestProgressService: failed to save progress: $e');
      return _defaultUnlockedLevel;
    }
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
      print('ForestProgressService: failed to load played levels: $e');
      return {};
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
