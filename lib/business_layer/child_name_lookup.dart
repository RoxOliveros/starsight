import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

//safety net for when the child name is renamed offline
Future<String?> tryGetChildDisplayName(String childId) async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('children')
        .doc(childId)
        .get()
        .timeout(const Duration(seconds: 8));

    final nickname = (doc.data()?['nickname'] as String?)?.trim();
    return (nickname == null || nickname.isEmpty) ? childId : nickname;
  } catch (_) {
    return null;
  }
}
