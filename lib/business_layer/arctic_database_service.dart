import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArcticDatabaseService {
  static const int _gamesPerCycle = 10;

  static Future<void> saveGameData({
    required String gameId,
    required int mistakes,
    required List<String> emotions,
  }) async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      final trackerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('category_progress')
          .doc('arctic_numberland');

      final trackerDoc = await trackerRef.get();
      int currentCycle = 1;

      if (trackerDoc.exists && trackerDoc.data()!.containsKey('currentCycle')) {
        currentCycle = trackerDoc.data()!['currentCycle'];
      } else {
        await trackerRef.set({
          'currentCycle': currentCycle,
        }, SetOptions(merge: true));
      }

      final currentCycleRef = trackerRef
          .collection('cycles')
          .doc('cycle_$currentCycle');

      final gamesSnapshot = await currentCycleRef
          .collection('games_played')
          .get();
      final distinctGameIdsPlayed = gamesSnapshot.docs
          .map((doc) => doc.data()['gameId'] as String?)
          .whereType<String>()
          .toSet();
      final totalDistinctGamesInCycle = distinctGameIdsPlayed.length;
      final gameAlreadyPlayed = distinctGameIdsPlayed.contains(gameId);

      if (totalDistinctGamesInCycle >= _gamesPerCycle && gameAlreadyPlayed) {
        currentCycle++;
        await trackerRef.set({
          'currentCycle': currentCycle,
        }, SetOptions(merge: true));
      }

      final saveRef = trackerRef
          .collection('cycles')
          .doc('cycle_$currentCycle');

      await saveRef.set({
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await saveRef.collection('games_played').add({
        'gameId': gameId,
        'mistakes': mistakes,
        'emotions': emotions,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving Arctic game data: $e");
    }
  }
}
