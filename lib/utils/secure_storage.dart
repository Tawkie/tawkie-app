import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageUtil {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> storeUserCreatedIndicator() async {
    await _secureStorage.write(key: 'userCreated', value: 'true');
  }

  static Future<void> clearUserCreatedIndicator() async {
    await _secureStorage.delete(key: 'userCreated');
  }

  static Future<String?> checkUserCreatedIndicator() async {
    return await _secureStorage.read(key: 'userCreated');
  }

  static Future<void> storeSessionToken(String? sessionToken) async {
    if (sessionToken != null) {
      await _secureStorage.write(key: 'sessionToken', value: sessionToken);
    }
  }

  static Future<String?> getSessionToken() async {
    return await _secureStorage.read(key: 'sessionToken');
  }

  static Future<void> storeUserUUID(String? userUUID) async {
    if (userUUID != null) {
      await _secureStorage.write(key: 'userUUID', value: userUUID);
    }
  }

  static Future<String?> getUserUUID() async {
    return await _secureStorage.read(key: 'userUUID');
  }
}
