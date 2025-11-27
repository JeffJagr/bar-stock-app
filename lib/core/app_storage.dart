import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';

/// Simple persistence service for saving/loading [AppState].
class AppStorage {
  static const _stateKey = 'smart_bar_state_v1';

  static Future<AppState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null) return AppState.initial();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppState.fromJson(map);
    } catch (_) {
      return AppState.initial();
    }
  }

  static Future<void> saveState(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.toJson());
    await prefs.setString(_stateKey, raw);
  }
}
