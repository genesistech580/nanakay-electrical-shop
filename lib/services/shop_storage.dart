import 'package:shared_preferences/shared_preferences.dart';

/// Restore the previous values if a multi-record update cannot be completed.
Future<void> saveShopRecords(
  SharedPreferences prefs,
  Map<String, String> updates,
) async {
  final previous = {for (final key in updates.keys) key: prefs.getString(key)};
  final attempted = <String>[];
  try {
    for (final entry in updates.entries) {
      attempted.add(entry.key);
      if (!await prefs.setString(entry.key, entry.value)) {
        throw StateError('Storage did not confirm the update.');
      }
    }
  } catch (_) {
    var restored = true;
    for (final key in attempted.reversed) {
      try {
        final value = previous[key];
        final saved = value == null
            ? await prefs.remove(key)
            : await prefs.setString(key, value);
        if (!saved) restored = false;
      } catch (_) {
        restored = false;
      }
    }
    throw StateError(
      restored
          ? 'Could not save the update. Previous records were restored.'
          : 'Storage failed and records could not be fully restored. Do not retry this transaction; restore a backup first.',
    );
  }
}
