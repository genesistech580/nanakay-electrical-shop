import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ShopProfile {
  const ShopProfile({
    this.name = 'NanaKay Electrical Shop',
    this.phone = '0557805124',
    this.address = '',
    this.email = '',
  });
  final String name;
  final String phone;
  final String address;
  final String email;
  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'address': address,
    'email': email,
  };
  static const storageKey = 'electrical_shop_profile_v1';
  factory ShopProfile.fromMap(Map<String, dynamic> data) => ShopProfile(
    name: data['name'] as String? ?? 'NanaKay Electrical Shop',
    phone: data['phone'] as String? ?? '0557805124',
    address: data['address'] as String? ?? '',
    email: data['email'] as String? ?? '',
  );
  static Future<ShopProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return const ShopProfile();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return ShopProfile(
      name: data['name'] as String? ?? 'NanaKay Electrical Shop',
      phone: data['phone'] as String? ?? '0557805124',
      address: data['address'] as String? ?? '',
      email: data['email'] as String? ?? '',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, jsonEncode(toMap()))) {
      throw StateError('Could not save shop details.');
    }
  }
}
