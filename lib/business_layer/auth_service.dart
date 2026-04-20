import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

class AuthService {
  // 1. GOOGLE SIGN-IN
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

  // 2. SEND MAGIC LINK
  Future<bool> sendMagicLink({required String email}) async {
    try {
      // NEW: Save the email locally before we send the link!
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('magic_email', email);

      var actionCodeSettings = ActionCodeSettings(
        url: 'https://starsight-app-10658.firebaseapp.com/',
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

  // 3. NEW: CATCH THE LINK AND LOG IN
  Future<bool> handleIncomingLink() async {
    final appLinks = AppLinks();

    try {
      final initialUri = await appLinks.getInitialLink();

      if (initialUri != null) {
        String link = initialUri.toString();

        // Check if it's a valid Firebase Magic Link
        if (FirebaseAuth.instance.isSignInWithEmailLink(link)) {
          // Retrieve the saved email
          final prefs = await SharedPreferences.getInstance();
          String? email = prefs.getString('magic_email');

          if (email != null) {
            // FINISH THE LOGIN!
            final userCredential = await FirebaseAuth.instance
                .signInWithEmailLink(email: email, emailLink: link);

            print(
              "MAGIC LINK SUCCESS! Logged in as: ${userCredential.user?.email}",
            );
            // Clear the saved email
            await prefs.remove('magic_email');
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print("Error catching magic link: $e");
      return false;
    }
  }
}
