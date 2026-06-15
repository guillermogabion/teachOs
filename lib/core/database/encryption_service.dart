import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _dbKeyName = 'teacheros_db_key';

  /// Retrieves the existing database password or generates a new one.
  static Future<String> getDatabasePassword() async {
    String? key = await _storage.read(key: _dbKeyName);

    if (key == null) {
      // Generate a highly secure random 32-character password
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64Url.encode(values);

      // Save it securely to the device
      await _storage.write(key: _dbKeyName, value: key);
    }

    return key;
  }
}
