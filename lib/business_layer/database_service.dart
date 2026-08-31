import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createParentAndChild({
    required String uid,
    String email = '',
    required String parentBirthYear,
    required String childNickname,
    required List<String> childGoals,
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
      'goals': childGoals,
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
          return doc.get('parentPin'); // <-- Grabs the PIN field
        }
      }
    } catch (e) {
      print("Error fetching PIN: $e");
    }
    return null;
  }


  // Future<List<Map<String, dynamic>>> getChildren() async {
  //   try {
  //     final User? currentUser = FirebaseAuth.instance.currentUser;
  //     if (currentUser == null) return [];
  //
  //     final QuerySnapshot snapshot = await _db
  //         .collection('users')
  //         .doc(currentUser.uid)
  //         .collection('children')
  //         .get();
  //
  //     return snapshot.docs
  //         .map((doc) =>
  //     {
  //       'id': doc.id, // this is the child's nickname (used as doc ID)
  //       ...doc.data() as Map<String, dynamic>,
  //     })
  //         .toList();
  //   } catch (e) {
  //     print("Error fetching children: $e");
  //     return [];
  //   }
  // }

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
          .map((doc) =>
      {
        'id': doc.id, // this is the child's nickname (used as doc ID)
        ...doc.data() as Map<String, dynamic>,
      })
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