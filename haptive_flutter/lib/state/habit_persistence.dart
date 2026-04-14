import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'habit_store.dart';

const _habitStoreKey = 'habit_store_v1';

/// Local persistence for [HabitStore] (offline + across restarts).
class HabitPersistence {
  static Future<HabitStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_habitStoreKey);
    if (raw == null || raw.isEmpty) {
      return HabitStore();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final store = HabitStore();
      store.replaceFromJson(map);
      return store;
    } catch (_) {
      return HabitStore();
    }
  }

  static Future<void> save(HabitStore store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_habitStoreKey, jsonEncode(store.toJson()));
  }
}
