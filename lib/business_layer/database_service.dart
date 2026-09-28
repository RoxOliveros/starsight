import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Screen time: parent picks from these presets (no free-text input).
  static const int defaultScreenTimeLimitMinutes = 30;
  static const List<int> screenTimeLimitOptions = [1, 15, 30, 45, 60];

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
        var childDoc = childrenDocs.docs.first;
        return childDoc.get('nickname');
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

  Future<void> updateChildAvatar({
    required String childNickname,
    required String avatarPath,
  }) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('children')
          .doc(childNickname)
          .update({'avatarPath': avatarPath});
    } catch (e) {
      print("Error updating child avatar: $e");
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
          .set({
            'screenTimeUsedSeconds': usedSeconds,
            'screenTimeDate': dateKey,
          }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving screen time usage: $e");
    }
  }
}

class ScreenTimeData {
  final int limitMinutes;
  final int usedSeconds;

  const ScreenTimeData({required this.limitMinutes, required this.usedSeconds});
}
