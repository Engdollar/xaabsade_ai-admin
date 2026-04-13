import 'package:flutter/material.dart';

import '../core/data/storage/prefs_store.dart';

class AppThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static Future<void> init(PrefsStore prefsStore) async {
    mode.value = await prefsStore.readThemeMode();
  }

  static Future<void> setMode(PrefsStore prefsStore, ThemeMode next) async {
    mode.value = next;
    await prefsStore.writeThemeMode(next);
  }
}
