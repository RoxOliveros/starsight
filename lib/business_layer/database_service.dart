import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

      if (currentUser != null) {
        QuerySnapshot childrenDocs = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('children')
            .limit(1)
            .get();

        if (childrenDocs.docs.isNotEmpty) {
          var childDoc = childrenDocs.docs.first;
          return childDoc.get('nickname');
        }
      }
    } catch (e) {
      print("Error fetching nickname: $e");
    }
    return null;
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
}
