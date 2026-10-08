import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Screen time: parent picks from these presets (no free-text input).
  static const int defaultScreenTimeLimitMinutes = 30;
  static const List<int> screenTimeLimitOptions = [0, 1, 15, 30, 45, 60];

  Future<void> createParentAndChild({
    required String uid,
    String email = '',
    required String parentBirthYear,
    required String childNickname,
    required String childBirthdate,
    required String childGender,
    required String parentPin,
  }) async {
    // Save to Firestore
    await _db.collection('users').doc(uid).set({
      'email': email,
      'parentBirthYear': parentBirthYear,
      'parentPin': parentPin,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db
        .collection('users')
        .doc(uid)
        .collection('children')
        .doc(childNickname)
        .set({
          'nickname': childNickname,
          'birthdate': childBirthdate,
          'gender': childGender,
          'screenTimeLimitMinutes': defaultScreenTimeLimitMinutes,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // Check if an email is already registered
  Future<bool> doesEmailExist(String email) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking email: $e");
      return false;
    }
  }

  Future<String?> getNickname() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final childrenRef = _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('children');

      // Prefer whichever child was last set active, so a cold app launch
      // resumes on the same profile the parent last selected.
      final userDoc = await _db.collection('users').doc(currentUser.uid).get();
      final activeChildNickname =
          userDoc.data()?['activeChildNickname'] as String?;

      if (activeChildNickname != null) {
        final activeDoc = await childrenRef.doc(activeChildNickname).get();
        if (activeDoc.exists) {
          return activeChildNickname;
        }
        // Falls through if the previously active child was deleted since.
      }

      // No persisted selection yet (e.g. first launch) — fall back to
      // whichever child comes back first.
      QuerySnapshot childrenDocs = await childrenRef.limit(1).get();

      if (childrenDocs.docs.isNotEmpty) {
        // Return the document ID (the stable key), not the editable
        // display nickname, since callers use this value as childId.
        return childrenDocs.docs.first.id;
      }
    } catch (e) {
      print("Error fetching nickname: $e");
    }
    return null;
  }

  Future<void> setActiveChild(String nickname) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _db.collection('users').doc(currentUser.uid).set({
        'activeChildNickname': nickname,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error setting active child: $e");
    }
  }

  Future<String?> getParentPin() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot doc = await _db
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          return doc.get('parentPin');
        }
      }
    } catch (e) {
      print("Error fetching PIN: $e");
    }
    return null;
  }

  Future<String?> updateParentPin(String newPin) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return "You're not signed in. Please sign in and try again.";
      }
      await _db.collection('users').doc(currentUser.uid).set({
        'parentPin': newPin,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      print("Error updating PIN: $e");
      return "Something went wrong while saving your new PIN. Please try again.";
    }
  }

  // Fetch the signed-in parent's birth year
  Future<String?> getParentBirthYear() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot doc = await _db
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          return doc.get('parentBirthYear') as String?;
        }
      }
    } catch (e) {
      print("Error fetching parent birth year: $e");
    }
    return null;
  }

  // Add another child under the currently signed-in parent's account.
  // Returns null on success, or a user-facing error message on failure.
  Future<String?> addChild({
    required String nickname,
    required String childBirthdate,
    required String childGender,
  }) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return "You're not signed in. Please sign in and try again.";
      }

      final childRef = _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('children')
          .doc(nickname);

      final existing = await childRef.get();
      if (existing.exists) {
        return 'A child named "$nickname" already exists. Please choose a different nickname.';
      }

      await childRef.set({
        'nickname': nickname,
        'birthdate': childBirthdate,
        'gender': childGender,
        'screenTimeLimitMinutes': defaultScreenTimeLimitMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      print("Error adding child: $e");
      return "Something went wrong while adding your child. Please try again.";
    }
  }

  Future<List<Map<String, dynamic>>> getChildren() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      final QuerySnapshot snapshot = await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('children')
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print("Error fetching children: $e");
      return [];
    }
  }

  Future<String?> updateChildAvatar({
    required String childId,
    required String avatarPath,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "You're not signed in.";

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(childId)
          .set({'avatarPath': avatarPath}, SetOptions(merge: true));
      return null;
    } catch (e) {
      print("Error updating child avatar: $e");
      return "Could not save the avatar. Please try again.";
    }
  }

  // ── SCREEN TIME ──────────────────────────────────────────────────────────

  /// Today's date in the device's local time (yyyy-MM-dd). Comparing this to
  /// the stored date is what makes the counter reset at 12:00 AM local time.
  static String todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Returns the child's limit and how much they've used *today*.
  /// Children created before this feature existed default to 30 minutes.
  Future<ScreenTimeData> getScreenTime(String childId) async {
    const fallback = ScreenTimeData(
      limitMinutes: defaultScreenTimeLimitMinutes,
      usedSeconds: 0,
    );
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return fallback;

      final doc = await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('children')
          .doc(childId)
          .get();
      final data = doc.data();
      if (data == null) return fallback;

      final limit =
          (data['screenTimeLimitMinutes'] as num?)?.toInt() ??
          defaultScreenTimeLimitMinutes;
      final savedDate = data['screenTimeDate'] as String?;
      final used = (savedDate == todayKey())
          ? ((data['screenTimeUsedSeconds'] as num?)?.toInt() ?? 0)
          : 0; // new day -> counter starts back at zero

      return ScreenTimeData(limitMinutes: limit, usedSeconds: used);
    } catch (e) {
      print("Error fetching screen time: $e");
      return fallback;
    }
  }

  /// Saves the parent's chosen daily limit. Returns true on success.
  Future<bool> setScreenTimeLimit(String childId, int minutes) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('children')
          .doc(childId)
          .set({'screenTimeLimitMinutes': minutes}, SetOptions(merge: true));
      return true;
    } catch (e) {
      print("Error saving screen time limit: $e");
      return false;
    }
  }

  /// Persists how many seconds the child has played on [dateKey].
  Future<void> saveScreenTimeUsage({
    required String childId,
    required int usedSeconds,
    required String dateKey,
  }) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('children')
          .doc(childId)
          .update({
            // was .set(..., SetOptions(merge: true))
            'screenTimeUsedSeconds': usedSeconds,
            'screenTimeDate': dateKey,
          });
    } catch (e) {
      print("Error saving screen time usage: $e");
    }
  }

  /// The name to show in the UI. Falls back to the doc ID for older docs.
  static String displayNameOf(Map<String, dynamic> child) =>
      ((child['nickname'] as String?)?.trim().isNotEmpty ?? false)
      ? (child['nickname'] as String).trim()
      : (child['id'] as String? ?? '');

  Future<String> getChildDisplayName(String childId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return childId;
      final doc = await _db
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(childId)
          .get();
      final n = (doc.data()?['nickname'] as String?)?.trim();
      return (n == null || n.isEmpty) ? childId : n;
    } catch (_) {
      return childId;
    }
  }

  /// Edits nickname / birthdate / gender. The document ID never changes,
  /// so progress and screen time stay attached to the child.
  /// Returns null on success, or a user-facing error message.
  Future<String?> updateChildInfo({
    required String childId,
    required String nickname,
    required String birthdate,
    required String gender,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return "You're not signed in. Please sign in and try again.";
      }

      final name = nickname.trim();

      if (name.isEmpty) {
        return 'Please enter a nickname.';
      }

      final childrenRef = _db
          .collection('users')
          .doc(user.uid)
          .collection('children');

      // Check if another child already has this nickname.
      final all = await childrenRef.get();

      final clash = all.docs.any((d) {
        // IMPORTANT:
        // Do not compare the child against itself.
        if (d.id == childId) return false;

        final otherNickname = ((d.data()['nickname'] as String?) ?? d.id)
            .trim();

        return otherNickname.toLowerCase() == name.toLowerCase();
      });

      if (clash) {
        return 'A child named "$name" already exists. Please choose a different nickname.';
      }

      // Update the existing document.
      // The document ID NEVER changes.
      await childrenRef.doc(childId).update({
        'nickname': name,
        'birthdate': birthdate,
        'gender': gender,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      print("Error updating child info: $e");
      return "Something went wrong while saving. Please try again.";
    }
  }

  // Categories that store progress under category_progress/{id}.
  // If you add a new category, add it here too, otherwise its data
  // is left behind when a child is deleted.
  static const List<String> _progressCategoryIds = [
    'alphabet_forest',
    'lumi_town',
    'arctic_numberland',
    'discovery_lagoon',
    'puzzle_glade',
  ];

  // cycle_1 ... cycle_N. Your reports only keep 2, this is just a safety margin.
  static const int _maxCyclesToClear = 5;

  /// Deletes every document in a collection (in batches of 400).
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    while (true) {
      final snap = await ref.limit(400).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// Permanently deletes a child and everything stored under them.
  /// Firestore does NOT delete subcollections when a document is deleted,
  /// so they are cleared first and the child document goes last. If
  /// something fails halfway, the child still exists and can be retried.
  /// Returns null on success, or a user-facing error message.
  Future<String?> deleteChild(String childId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return "You're not signed in. Please sign in and try again.";
      }

      final userRef = _db.collection('users').doc(user.uid);
      final childrenRef = userRef.collection('children');

      final all = await childrenRef.get();
      if (!all.docs.any((d) => d.id == childId)) {
        return 'This child profile no longer exists.';
      }
      if (all.docs.length <= 1) {
        return "You can't delete the only child profile. Add another child first.";
      }

      final childRef = childrenRef.doc(childId);

      // 1. Progress: category_progress/{category}/cycles/cycle_N/games_played
      final progressRef = childRef.collection('category_progress');
      for (final categoryId in _progressCategoryIds) {
        final categoryRef = progressRef.doc(categoryId);
        for (var slot = 1; slot <= _maxCyclesToClear; slot++) {
          final cycleRef = categoryRef.collection('cycles').doc('cycle_$slot');
          await _deleteCollection(cycleRef.collection('games_played'));
          await cycleRef.delete();
        }
        await categoryRef.delete();
      }
      await _deleteCollection(progressRef); // anything else left at that level

      // 2. The child document itself.
      await childRef.delete();

      // 3. If this was the active child, point to one that still exists.
      final userDoc = await userRef.get();
      if (userDoc.data()?['activeChildNickname'] == childId) {
        final nextId = all.docs.firstWhere((d) => d.id != childId).id;
        await userRef.set({
          'activeChildNickname': nextId,
        }, SetOptions(merge: true));
      }

      return null;
    } catch (e) {
      print("Error deleting child: $e");
      return "Something went wrong while deleting. Please try again.";
    }
  }
}

class ScreenTimeData {
  final int limitMinutes;
  final int usedSeconds;

  const ScreenTimeData({required this.limitMinutes, required this.usedSeconds});
}
