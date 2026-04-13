import 'package:flutter/material.dart';
import 'app/app_theme_controller.dart';
import 'app/kaaliye_app.dart';
import 'core/data/storage/prefs_store.dart';
import 'core/data/storage/secure_store.dart';
import 'core/data/telesom/telesom_api_client.dart';
import 'core/services/auto_transfer_background_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  AutoTransferBackgroundService.init();
  final prefsStore = PrefsStore();
  await AppThemeController.init(prefsStore);
  runApp(
    XaabsadeApp(
      apiClient: TelesomApiClient(),
      secureStore: SecureStore(),
      prefsStore: prefsStore,
      // Pass logo asset path for splash/login screens
      logoAsset: 'assets/images/xaabsade_logo.png',
    ),
  );
}
