import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShopSecurityService {
  ShopSecurityService._();
  static final instance = ShopSecurityService._();

  static const _pinKey = 'electrical_shop_owner_pin_v1';
  static const _secureStorage = FlutterSecureStorage();
  static const _salt = 'nanakay_electrical_shop_salt_2026_';

  String hashPassword(String password) {
    final bytes = utf8.encode('$_salt$password');
    return sha256.convert(bytes).toString();
  }

  /// Checks if a password has been configured either locally or in the cloud database.
  Future<bool> isSetupRequired() async {
    // 1. Check local secure storage
    try {
      final securePin = await _secureStorage.read(key: _pinKey);
      if (securePin != null && securePin.trim().isNotEmpty) {
        return false;
      }
    } catch (_) {}

    // 2. Check local shared preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final localPin = prefs.getString(_pinKey);
      if (localPin != null && localPin.trim().isNotEmpty) {
        return false;
      }
    } catch (_) {}

    // 3. Check Supabase cloud database
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('shop_security')
          .select('pin_hash')
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (response != null && response['pin_hash'] != null) {
        final hash = response['pin_hash'] as String?;
        if (hash != null && hash.isNotEmpty) {
          return false;
        }
      }
    } catch (_) {
      // If offline or table not created yet, fallback to local status
    }

    return true;
  }

  /// Reads the local password if stored on this device.
  Future<String?> readLocalPassword() async {
    try {
      final securePin = await _secureStorage.read(key: _pinKey);
      if (securePin != null && securePin.trim().isNotEmpty) {
        return securePin;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pinKey);
    } catch (_) {}

    return null;
  }

  /// Saves the password to both local persistent storage and the database.
  Future<void> savePassword(String password) async {
    final trimmed = password.trim();

    // 1. Save to local secure storage
    try {
      await _secureStorage.write(key: _pinKey, value: trimmed);
    } catch (_) {}

    // 2. Save to local SharedPreferences database
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, trimmed);
    } catch (_) {}

    // 3. Save hashed password to Supabase database
    try {
      final client = Supabase.instance.client;
      final pinHash = hashPassword(trimmed);
      await client.from('shop_security').upsert({
        'id': 1,
        'pin_hash': pinHash,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Table may not have been created yet in Supabase or client is offline.
      // Local database storage succeeded so the app remains fully functional.
    }
  }

  /// Verifies the entered password against local storage or the database.
  Future<bool> verifyPassword(String enteredPassword) async {
    final trimmed = enteredPassword.trim();

    // 1. Check local saved password
    final localPin = await readLocalPassword();
    if (localPin != null && localPin.trim() == trimmed) {
      return true;
    }

    // 2. Check against Supabase cloud database
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('shop_security')
          .select('pin_hash')
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (response != null && response['pin_hash'] != null) {
        final expectedHash = response['pin_hash'] as String;
        final enteredHash = hashPassword(trimmed);
        if (expectedHash == enteredHash) {
          // Sync and cache valid password locally on this device
          await savePassword(trimmed);
          return true;
        }
      }
    } catch (_) {}

    return false;
  }
}
