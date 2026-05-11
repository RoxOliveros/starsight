import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createParentAndChild({
    required String uid,
    required String email,
    required String parentBirthYear, // <--- This fixes the first error!
    required String childNickname,
    required String childAge,
    required List<String> childGoals,
  }) async {
    // Save to Firestore
    await _db.collection('users').doc(uid).set({
      'email': email,
      'parentBirthYear': parentBirthYear,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db
        .collection('users')
        .doc(uid)
        .collection('children')
        .doc(childNickname)
        .set({
          'nickname': childNickname,
          'age': childAge,
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

  Future<String> getNickname() async {
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
          return childDoc.get('nickname') ?? "Little Explorer";
        }
      }
    } catch (e) {
      print("Error fetching nickname: $e");
    }

    return "Little Explorer";
  }

  // --- NEW FUNCTION: Get the Parent's PIN ---
  // (This fixes the second error!)
  Future<String?> getParentBirthYear() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot doc = await _db
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          return doc.get('parentBirthYear');
        }
      }
    } catch (e) {
      print("Error fetching birth year: $e");
    }
    return null;
  }
}
