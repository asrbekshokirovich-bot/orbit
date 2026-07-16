import 'package:flutter/foundation.dart';
import 'api.dart';
import 'store.dart';

/// Tiny global app state: the current key (drives gate vs app) and a cached
/// businesses list shared across tabs.
class AppState {
  static final ValueNotifier<String?> key = ValueNotifier<String?>(null);
  static List<Map<String, dynamic>> businesses = <Map<String, dynamic>>[];

  static Future<void> init() async {
    key.value = await Store.getKey();
  }

  static Future<void> setKey(String k) async {
    await Store.setKey(k);
    key.value = k.trim();
  }

  static Future<void> expire() async {
    await Store.clearKey();
    businesses = <Map<String, dynamic>>[];
    key.value = null;
  }

  static Future<List<Map<String, dynamic>>> loadBusinesses(
      {bool force = false}) async {
    if (businesses.isNotEmpty && !force) return businesses;
    final d = await Api.instance.call('overview');
    final list = (d['businesses'] as List?) ?? const [];
    businesses = list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    return businesses;
  }
}

String fmtAmount(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}
