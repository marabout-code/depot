import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../models/user_model.dart';

class SecureStorageService {
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  SecureStorageService()
      : _secureStorage = const FlutterSecureStorage();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.secureTokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.secureTokenKey);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: AppConstants.secureTokenKey);
  }

  Future<void> saveRole(String role) async {
    await _secureStorage.write(key: AppConstants.secureRoleKey, value: role);
  }

  Future<String?> getRole() async {
    return await _secureStorage.read(key: AppConstants.secureRoleKey);
  }

  Future<void> deleteRole() async {
    await _secureStorage.delete(key: AppConstants.secureRoleKey);
  }

  Future<void> setRememberMe(bool value) async {
    await _prefs?.setBool(AppConstants.rememberMeKey, value);
  }

  Future<bool> getRememberMe() async {
    return _prefs?.getBool(AppConstants.rememberMeKey) ?? false;
  }

  Future<void> setSavedEmail(String email) async {
    await _prefs?.setString(AppConstants.savedEmailKey, email);
  }

  Future<String?> getSavedEmail() async {
    return _prefs?.getString(AppConstants.savedEmailKey);
  }

  Future<void> cacheUser(UserModel user) async {
    final json = jsonEncode(user.toMap());
    await _prefs?.setString(AppConstants.cachedUserKey, json);
  }

  Future<UserModel?> getCachedUser() async {
    final json = _prefs?.getString(AppConstants.cachedUserKey);
    if (json == null) return null;
    try {
      return UserModel.fromMap(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedUser() async {
    await _prefs?.remove(AppConstants.cachedUserKey);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs?.clear();
  }
}
