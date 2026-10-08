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

  // 6. RE-VERIFY THE SIGNED-IN PARENT (used by Forgot PIN)
  // Which sign-in methods the current account uses, e.g. 'password', 'google.com'.
  List<String> get signInProviders =>
      FirebaseAuth.instance.currentUser?.providerData
          .map((p) => p.providerId)
          .toList() ??
      [];

  // Returns null if the password is correct, or an error message if not.
  Future<String?> reauthenticateWithPassword(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return "You're not signed in. Please sign in and try again.";
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return null; // Success!
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return "That password isn't right. Please try again.";
      }
      if (e.code == 'too-many-requests') {
        return "Too many tries. Please wait a few minutes and try again later.";
      }
      return e.message ?? "Could not verify your password.";
    } catch (e) {
      return "An unknown error occurred.";
    }
  }

  // Returns null if verified, or an error message (also if cancelled).
  Future<String?> reauthenticateWithGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return "You're not signed in. Please sign in and try again.";
    }
    try {
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: googleAuth.idToken),
      );
      return null; // Success!
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-mismatch') {
        return "Please choose the Google account you signed up with.";
      }
      return e.message ?? "Could not verify with Google.";
    } catch (e) {
      print("Error during Google re-verification: $e");
      return "Could not verify with Google. Please try again.";
    }
  }
}
