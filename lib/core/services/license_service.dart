import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';

final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService();
});

enum LicenseStatus { trial, trialExpired, activated }

class LicenseService {
  LicenseStatus _status = LicenseStatus.trial;
  String _deviceId = '';
  int _remainingDays = 30;

  LicenseStatus get status => _status;
  String get deviceId => _deviceId;
  int get remainingDays => _remainingDays;
  bool get isActivated => _status == LicenseStatus.activated;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _deviceId = prefs.getString(AppConstants.deviceIdKey) ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = const Uuid().v4();
      await prefs.setString(AppConstants.deviceIdKey, _deviceId);
    }

    final activated = prefs.getBool(AppConstants.licenseActivatedKey) ?? false;
    if (activated) {
      final storedKey = prefs.getString(AppConstants.licenseKeyStored) ?? '';
      if (verifyKey(storedKey)) {
        _status = LicenseStatus.activated;
        return;
      }
    }

    final firstLaunch = prefs.getString(AppConstants.licenseFirstLaunchKey);
    if (firstLaunch == null) {
      await prefs.setString(
          AppConstants.licenseFirstLaunchKey, DateTime.now().toIso8601String());
      _status = LicenseStatus.trial;
      _remainingDays = AppConstants.trialDays;
      return;
    }

    final start = DateTime.parse(firstLaunch);
    final elapsed = DateTime.now().difference(start).inDays;
    if (elapsed >= AppConstants.trialDays) {
      _status = LicenseStatus.trialExpired;
      _remainingDays = 0;
    } else {
      _status = LicenseStatus.trial;
      _remainingDays = AppConstants.trialDays - elapsed;
    }
  }

  static String _hmacHex(String data, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(utf8.encode(data)).toString();
  }

  bool verifyKey(String licenseKey) {
    final trimmed = licenseKey.trim();
    if (trimmed.length != 64) return false;

    final expected = _hmacHex(_deviceId, AppConstants.licenseSecret);
    if (trimmed == expected) return true;

    final masterExpected =
        _hmacHex(AppConstants.masterKeySentinel, AppConstants.licenseSecret);
    if (trimmed == masterExpected) return true;

    return false;
  }

  Future<bool> activate(String licenseKey) async {
    if (!verifyKey(licenseKey)) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.licenseActivatedKey, true);
    await prefs.setString(AppConstants.licenseKeyStored, licenseKey.trim());
    _status = LicenseStatus.activated;
    return true;
  }
}
