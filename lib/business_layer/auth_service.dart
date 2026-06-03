import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // --- 1. START PHONE VERIFICATION ---
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function() onVerificationCompleted,
  }) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          onVerificationCompleted();
        },

        verificationFailed: (FirebaseAuthException e) {
          print("Phone Auth Failed: ${e.message}");
          onError(e.message ?? "Verification failed. Please check the number.");
        },

        codeSent: (String verificationId, int? resendToken) {
          print("SMS sent successfully!");
          onCodeSent(verificationId);
        },

        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError("An error occurred. Please try again.");
    }
  }

  Future<bool> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      print(
        "Success! Logged in with Phone: ${userCredential.user?.phoneNumber}",
      );

      return true;
    } catch (e) {
      print("Invalid OTP or error: $e");
      return false;
    }
  }
}
