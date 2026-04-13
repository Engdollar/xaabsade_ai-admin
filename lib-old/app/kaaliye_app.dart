import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/data/storage/prefs_store.dart';
import '../core/data/storage/secure_store.dart';
import '../core/data/telesom/telesom_api_client.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import 'app_theme_controller.dart';
import '../ui/blueprint/blueprint_widgets.dart';

class XaabsadeApp extends StatefulWidget {
  const XaabsadeApp({
    super.key,
    required this.apiClient,
    required this.secureStore,
    required this.prefsStore,
    this.logoAsset = 'assets/images/xaabsade_logo.png',
  });

  final TelesomApiClient apiClient;
  final SecureStore secureStore;
  final PrefsStore prefsStore;
  final String logoAsset;

  @override
  State<XaabsadeApp> createState() => _XaabsadeAppState();
}

class _XaabsadeAppState extends State<XaabsadeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keepScreenOn();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _allowScreenOff();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _keepScreenOn();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _allowScreenOff();
    }
  }

  Future<void> _keepScreenOn() async {
    await WakelockPlus.enable();
  }

  Future<void> _allowScreenOff() async {
    await WakelockPlus.disable();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, themeMode, _) {
        return WithForegroundTask(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Xaabsade AI',
            themeMode: themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: Brightness.dark,
              ),
            ),
            home: SplashGate(
              apiClient: widget.apiClient,
              secureStore: widget.secureStore,
              prefsStore: widget.prefsStore,
              logoAsset: widget.logoAsset,
            ),
          ),
        );
      },
    );
  }
}

/// Shows splash for a fixed duration, then proceeds to session check.
class _AnimatedSplash extends StatefulWidget {
  final String logoAsset;
  const _AnimatedSplash({this.logoAsset = 'assets/images/xaabsade_logo.png'});

  @override
  State<_AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<_AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  late final Animation<double> _float;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    const inTest = bool.fromEnvironment('FLUTTER_TEST');
    if (inTest) {
      _c.value = 1.0;
    } else {
      _c.repeat(reverse: true);
    }

    final curved = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.94, end: 1.04).animate(curved);
    _glow = Tween<double>(begin: 0.18, end: 0.38).animate(curved);
    _float = Tween<double>(begin: -6, end: 6).animate(curved);
    _fadeIn = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: const Interval(0.2, 1.0)));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BlueprintBackground(),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _glow,
                builder: (context, child) {
                  return Opacity(opacity: _glow.value, child: child);
                },
                child: _SoftBlob(
                  color: BlueprintTokens.accent.withValues(alpha: 0.18),
                  size: 200,
                ),
              ),
              AnimatedBuilder(
                animation: _scale,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _float.value),
                    child: Transform.scale(scale: _scale.value, child: child),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: BlueprintTokens.accent.withValues(alpha: 0.35),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Image.asset(widget.logoAsset, width: 120, height: 120),
                ),
              ),
              AnimatedBuilder(
                animation: _fadeIn,
                builder: (context, child) {
                  return Opacity(opacity: _fadeIn.value, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 150),
                  child: Text(
                    'Initializing blueprint...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BlueprintTokens.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoftBlob extends StatelessWidget {
  const _SoftBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 90,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

/// SplashGate widget definition (missing in file)
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.apiClient,
    required this.secureStore,
    required this.prefsStore,
    required this.logoAsset,
  });

  final TelesomApiClient apiClient;
  final SecureStore secureStore;
  final PrefsStore prefsStore;
  final String logoAsset;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;
  StoredSession? _session;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    const inTest = bool.fromEnvironment('FLUTTER_TEST');
    final delay = inTest ? Duration.zero : const Duration(seconds: 2);
    await Future.delayed(delay); // Splash duration
    _session = await widget.secureStore.readSession();
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return _AnimatedSplash(logoAsset: widget.logoAsset);
    }
    if (_session == null ||
        _session!.token == null ||
        _session!.token!.isEmpty) {
      return LoginScreen(
        apiClient: widget.apiClient,
        secureStore: widget.secureStore,
        prefsStore: widget.prefsStore,
        logoAsset: widget.logoAsset,
      );
    }
    return DashboardScreen(
      apiClient: widget.apiClient,
      secureStore: widget.secureStore,
      prefsStore: widget.prefsStore,
      initialSession: _session!,
    );
  }
}
