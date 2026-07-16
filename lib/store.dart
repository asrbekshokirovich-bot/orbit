import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for the Orbit access key (device-only, never bundled).
class Store {
  static const _kKey = 'orbit_key';

  static Future<String?> getKey() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> setKey(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, key.trim());
  }

  static Future<void> clearKey() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}
