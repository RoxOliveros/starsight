import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createParentAndChild({
    required String uid,
    String email = '', // <-- Default empty string
    String phoneNumber =
        '', // <-- Default empty string // holds phone number for now
    required String parentBirthYear,
    required String childNickname,
    required List<String> childGoals,
    required String parentPin,
  }) async {
    // Save to Firestore
    await _db.collection('users').doc(uid).set({
      'email': email, // Saves the SMS phone (if any)
      'phoneNumber': phoneNumber, // Saves the SMS phone (if any)
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

  Future<bool> doesPhoneExist(String phone) async {
    try {
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
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
}
