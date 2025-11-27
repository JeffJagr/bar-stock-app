import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordUtils {
  static final Random _random = Random.secure();

  static String generateSalt([int length = 16]) {
    final bytes =
        List<int>.generate(length, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPassword(
    String password,
    String salt,
    String expectedHash,
  ) {
    return hashPassword(password, salt) == expectedHash;
  }
}
