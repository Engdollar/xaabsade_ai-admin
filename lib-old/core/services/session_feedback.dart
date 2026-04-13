import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Provides a consistent haptic + audible signal whenever the app ends a session.
class SessionFeedback {
  const SessionFeedback._();

  static bool _isSupportedPlatform() {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  static Future<void> sessionTerminated() async {
    if (!_isSupportedPlatform()) return;
    final futures = <Future<void>>[];
    try {
      futures.add(HapticFeedback.heavyImpact());
    } catch (_) {}
    try {
      futures.add(SystemSound.play(SystemSoundType.alert));
    } catch (_) {}
    if (futures.isEmpty) return;
    await Future.wait(futures, eagerError: false);
  }
}
