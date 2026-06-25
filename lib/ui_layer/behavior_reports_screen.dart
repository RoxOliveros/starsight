import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Using your existing color palette
abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color warmBrown = Color(0xFF5E463E);
}

class BehaviorReportsScreen extends StatelessWidget {
  const BehaviorReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the ID of the parent currently logged into the app
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: ColorTheme.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ColorTheme.warmBrown),
        title: const Text(
          "Behavior Reports",
          style: TextStyle(
            fontFamily: 'Fredoka',
            color: ColorTheme.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: currentUserId.isEmpty
          ? const Center(child: Text("Please log in first."))
          : StreamBuilder<QuerySnapshot>(
              // Listens to the exact database path where your Star Color Sort game saves the data!
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .collection('reports')
                  .orderBy('timestamp', descending: true) // Newest first
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No reports yet! Play a game to generate one.",
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        color: ColorTheme.warmBrown,
                      ),
                    ),
                  );
                }

                // We have data! Let's display it.
                final reports = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final data = reports[index].data() as Map<String, dynamic>;
                    final activityName =
                        data['activityName'] ?? 'Unknown Activity';
                    final summary = data['summary'] ?? 'No summary available.';
                    final timestamp = data['timestamp'] as Timestamp?;

                    // Format the date so it looks nice for the parents
                    String dateString = "Just now";
                    if (timestamp != null) {
                      DateTime date = timestamp.toDate();
                      dateString =
                          "${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  activityName,
                                  style: const TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: ColorTheme.deepNavyBlue,
                                  ),
                                ),
                                Text(
                                  dateString,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              summary,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
