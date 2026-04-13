import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'data/repositories/firestore_repository.dart';
import 'firebase_options.dart';
import 'state/account_provider.dart';
import 'state/account_selection_provider.dart';
import 'state/device_provider.dart';
import 'state/subscription_provider.dart';
import 'state/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FirestoreRepository()),
        ChangeNotifierProvider(create: (_) => AccountSelectionProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) =>
              AccountProvider(context.read<FirestoreRepository>()),
        ),
        ChangeNotifierProxyProvider2<
          FirestoreRepository,
          AccountProvider,
          SubscriptionProvider
        >(
          create: (context) =>
              SubscriptionProvider(context.read<FirestoreRepository>()),
          update: (context, repo, accountProvider, provider) {
            provider ??= SubscriptionProvider(repo);
            provider.updateRepository(repo);
            provider.updateAccounts(accountProvider.accounts);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<
          FirestoreRepository,
          AccountSelectionProvider,
          DeviceProvider
        >(
          create: (context) =>
              DeviceProvider(context.read<FirestoreRepository>()),
          update: (context, repo, selection, provider) {
            provider ??= DeviceProvider(repo);
            provider.updateRepository(repo);
            provider.bindAccount(selection.accountId);
            return provider;
          },
        ),
      ],
      child: const XaabsadeApp(),
    ),
  );
}
