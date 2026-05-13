import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:StarSight/business_layer/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // GOOGLE SIGN-IN
  Future<bool> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      print("Success! Logged in as: ${userCredential.user?.email}");
      return true;
    } catch (e) {
      print("Error during Google Sign-In: $e");
      return false;
    }
  }

  Future<bool> sendMagicLink({
    required String email,
    required String nickname,
    required String age,
    required List<String> goals,
    required String parentBirthYear,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('temp_signups')
          .doc(email)
          .set({
            'nickname': nickname,
            'age': age,
            'goals': goals,
            'parentBirthYear': parentBirthYear,
          });

      // 2. ONLY PUT EMAIL AND TYPE IN THE LINK!
      // (This keeps the link short so email apps don't chop it off)
      Uri dynamicUri = Uri.https('starsight-app-10658.firebaseapp.com', '/', {
        'email': email,
        'type': 'signup', // <-- Just the email and type, nothing else!
      });

      var actionCodeSettings = ActionCodeSettings(
        url: dynamicUri.toString(),
        handleCodeInApp: true,
        androidPackageName: 'com.example.starsight',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      print("Magic link sent successfully to $email");
      return true;
    } catch (e) {
      print("Error sending magic link: $e");
      return false;
    }
  }

  Future<bool> sendLoginMagicLink({required String email}) async {
    try {
      // THE FIX: Use Uri.https for the login link too!
      Uri dynamicUri = Uri.https('starsight-app-10658.firebaseapp.com', '/', {
        'email': email,
        'type': 'login',
      });

      var actionCodeSettings = ActionCodeSettings(
        url: dynamicUri.toString(), // <--- Safe URL!
        handleCodeInApp: true,
        androidPackageName: 'com.example.starsight',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      print("Login magic link sent successfully to $email");
      return true;
    } catch (e) {
      print("Error sending login magic link: $e");
      return false;
    }
  }

  // CATCH THE LINK AND UNPACK IT
  Future<String> handleIncomingLink() async {
    final appLinks = AppLinks();

    try {
      final initialUri = await appLinks.getInitialLink();

      if (initialUri != null) {
        String link = initialUri.toString();

        if (FirebaseAuth.instance.isSignInWithEmailLink(link)) {
          String? email = initialUri.queryParameters['email'];
          String? type = initialUri.queryParameters['type'];

          if (email != null) {
            final userCredential = await FirebaseAuth.instance
                .signInWithEmailLink(email: email, emailLink: link);

            // 3. If it was a Sign Up, grab data from the waiting room!
            if (type == 'signup') {
              DocumentSnapshot tempDoc = await FirebaseFirestore.instance
                  .collection('temp_signups')
                  .doc(email)
                  .get();

              if (tempDoc.exists) {
                Map<String, dynamic> data =
                    tempDoc.data() as Map<String, dynamic>;

                // Safely extract goals
                List<String> goals = [];
                if (data['goals'] != null) {
                  goals = List<String>.from(data['goals']);
                }

                // Push everything to the official database profile!
                await DatabaseService().createParentAndChild(
                  uid: userCredential.user!.uid,
                  email: email,
                  childNickname: data['nickname'],
                  childAge: data['age'],
                  childGoals: goals,
                  parentBirthYear: data['parentBirthYear'],
                );

                // Clean up the waiting room
                await FirebaseFirestore.instance
                    .collection('temp_signups')
                    .doc(email)
                    .delete();
              }
            }

            return type == 'login' ? "login" : "signup";
          }
        }
      }
      return "none";
    } catch (e) {
      print("Error catching magic link: $e");
      return "none";
    }
  }
}
