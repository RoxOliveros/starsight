import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArcticDatabaseService {
  /// Saves gameplay data to the current active cycle.
  /// If all 5 target levels are completed and a game is replayed, it automatically creates a new cycle.
  static Future<void> saveGameData({
    required String gameId,
    required int mistakes,
    required List<String> emotions,
  }) async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. Point to the Arctic Numberland category tracker
      final trackerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('category_progress')
          .doc('arctic_numberland');

      // 2. Fetch or create the current cycle number
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

      // 3. SMART DUPLICATE CHECK: Prevent database fragmentation!
      final gamesSnapshot = await currentCycleRef
          .collection('games_played')
          .get();
      int totalGamesInCycle = gamesSnapshot.docs.length;
      bool gameAlreadyPlayed = gamesSnapshot.docs.any(
        (doc) => doc.id == gameId,
      );

      // Threshold is set to 5 for the capstone tracking scope!
      if (totalGamesInCycle >= 5 && gameAlreadyPlayed) {
        currentCycle++;
        await trackerRef.set({
          'currentCycle': currentCycle,
        }, SetOptions(merge: true));
      }

      // 4. Save the data to the correct, verified cycle folder
      final saveRef = trackerRef
          .collection('cycles')
          .doc('cycle_$currentCycle');

      // Update the timestamp so the parent's dashboard shows the latest playtime
      await saveRef.set({
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save the actual game results
      await saveRef.collection('games_played').doc(gameId).set({
        'mistakes': mistakes,
        'emotions': emotions,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving Arctic game data: $e");
    }
  }
}
