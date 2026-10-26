import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player progress (S8): the total number of suns (energy
/// orbs) banked across runs at run end. Suns unlock worlds per
/// GameConfig.worldUnlockSunsFor.
class ProgressStore {
  ProgressStore._(this._prefs);

  final SharedPreferences? _prefs;
  int _memoryTotal = 0;

  static const String _totalSunsKey = 'sdr_total_suns';

  /// Total banked suns (never negative).
  int get totalSuns => _prefs?.getInt(_totalSunsKey) ?? _memoryTotal;

  /// Loads the store. When persistence is unavailable (e.g. a plugin
  /// channel missing in a test harness) an in-memory store is used so
  /// gameplay is never blocked.
  static Future<ProgressStore> load() async {
    try {
      return ProgressStore._(await SharedPreferences.getInstance());
    } catch (_) {
      return ProgressStore._(null);
    }
  }

  /// Banks [count] newly collected suns; returns the new total.
  Future<int> addSuns(int count) async {
    if (count <= 0) {
      return totalSuns;
    }
    final total = totalSuns + count;
    final prefs = _prefs;
    if (prefs == null) {
      _memoryTotal = total;
      return total;
    }
    try {
      await prefs.setInt(_totalSunsKey, total);
    } catch (_) {
      // persistence loss is non-fatal: gameplay continues this session
    }
    return total;
  }
}
