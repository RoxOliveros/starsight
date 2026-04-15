import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  Future<void> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();

      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();

      // If they click outside the box to cancel, just stop
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      print("Success! Logged in as: ${userCredential.user?.email}");
    } catch (e) {
      print("Error during Google Sign-In: $e");
    }
  }
}
