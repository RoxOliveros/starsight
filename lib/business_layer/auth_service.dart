import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

      await FirebaseAuth.instance.signInWithCredential(credential);
      return true;
    } catch (e) {
      print("Error during Google Sign-In: $e");
      return false;
    }
  }

  // 2. EMAIL SIGN UP
  // Returns null if successful, or an error message string if it fails.
  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success!
    } on FirebaseAuthException catch (e) {
      return e
          .message; // Returns Firebase errors like "Password too weak" or "Email already in use"
    } catch (e) {
      return "An unknown error occurred.";
    }
  }

  // 3. EMAIL SIGN IN
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success!
    } on FirebaseAuthException catch (e) {
      return e.message; // Returns errors like "Invalid credentials"
    } catch (e) {
      return "An unknown error occurred.";
    }
  }

  // 4. FORGOT PASSWORD RESET
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null; // Success!
    } on FirebaseAuthException catch (e) {
      // Intercept the Firebase spam filter error
      if (e.code == 'too-many-requests') {
        return "Too many tries. Please wait a few minutes and try again later.";
      }
      // Intercept the ugly auth credential error you saw
      if (e.code == 'invalid-credential' || e.code == 'expired-action-code') {
        return "Your request has expired or is invalid. Please try again.";
      }
      return e.message;
    } catch (e) {
      return "An unknown error occurred.";
    }
  }

  // 5. CONFIRM NEW PASSWORD
  Future<String?> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      return null; // Success!
    } on FirebaseAuthException catch (e) {
      print("confirmPasswordReset error: ${e.code} — ${e.message}");
      return e.message;
    } catch (e) {
      print("confirmPasswordReset unknown error: $e");
      return "An unknown error occurred.";
    }
  }
}
