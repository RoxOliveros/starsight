import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Hashes and verifies the parent PIN so the real PIN is never stored.
class PinHelper {
  /// Random per-user salt, so identical PINs produce different hashes.
  static String generateSalt([int length = 16]) {
    final rand = Random.secure();
    return base64UrlEncode(
      List<int>.generate(length, (_) => rand.nextInt(256)),
    );
  }

  /// Iterated HMAC-SHA256 (PBKDF2-style stretching).
  static String hashPin(String pin, String salt, {int iterations = 10000}) {
    final key = utf8.encode(salt);
    var digest = Hmac(sha256, key).convert(utf8.encode(pin)).bytes;
    for (var i = 1; i < iterations; i++) {
      digest = Hmac(sha256, key).convert(digest).bytes;
    }
    return base64UrlEncode(digest);
  }

  /// Constant-time comparison of the entered PIN against the stored hash.
  static bool verify(String enteredPin, String salt, String storedHash) {
    final computed = hashPin(enteredPin, salt);
    if (computed.length != storedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < computed.length; i++) {
      diff |= computed.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}
