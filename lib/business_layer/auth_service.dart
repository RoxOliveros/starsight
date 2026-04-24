import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:StarSight/business_layer/database_service.dart';

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

  // SEND MAGIC LINK
  Future<bool> sendMagicLink({
    required String email,
    required String nickname,
    required String age,
    required List<String> goals,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('magic_email', email);
      await prefs.setString('child_nickname', nickname);
      await prefs.setString('child_age', age);
      await prefs.setStringList('child_goals', goals);

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
      if (e is FirebaseAuthException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
      }
      return false;
    }
  }

  // SEND MAGIC LINK (FOR SIGN IN)
  Future<bool> sendLoginMagicLink({required String email}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('magic_email', email);
      await prefs.setBool('is_login_only', true);

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

      print("Login magic link sent successfully to $email");
      return true;
    } catch (e) {
      print("Error sending login magic link: $e");
      return false;
    }
  }

  // CATCH THE LINK AND LOG IN
  Future<String> handleIncomingLink() async {
    final appLinks = AppLinks();

    try {
      final initialUri = await appLinks.getInitialLink();

      // Checks if the app was opened with a magic link
      if (initialUri != null) {
        String link = initialUri.toString();

        if (FirebaseAuth.instance.isSignInWithEmailLink(link)) {
          final prefs = await SharedPreferences.getInstance();
          String? email = prefs.getString('magic_email');
          bool isLoginOnly = prefs.getBool('is_login_only') ?? false;

          if (email != null) {
            final userCredential = await FirebaseAuth.instance
                .signInWithEmailLink(email: email, emailLink: link);

            // If it was a Sign UP, save the child data to Firestore
            if (!isLoginOnly) {
              String? nickname = prefs.getString('child_nickname');
              String? age = prefs.getString('child_age');
              List<String>? goals = prefs.getStringList('child_goals');

              if (userCredential.user != null &&
                  nickname != null &&
                  age != null &&
                  goals != null) {
                await DatabaseService().createParentAndChild(
                  uid: userCredential.user!.uid,
                  email: email,
                  childNickname: nickname,
                  childAge: age,
                  childGoals: goals,
                );
              }
            }

            // Clear the backpack
            await prefs.clear();

            // RETURN THE ROUTE!
            return isLoginOnly ? "login" : "signup";
          }
        }
      }

      // Automatic login if user is already authenticated @everyone Wag muna galawin nasa testing pa lang
      //  if (FirebaseAuth.instance.currentUser != null) {
      //   return "login"; // User automatically go to dashboard if they are already logged in
      //}

      return "none";
    } catch (e) {
      print("Error catching magic link: $e");
      return "none";
    }
  }
}
