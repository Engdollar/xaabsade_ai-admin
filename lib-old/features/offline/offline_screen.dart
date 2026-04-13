import 'package:flutter/material.dart';
import '../../ui/blueprint/blueprint_widgets.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlueprintBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: BlueprintPanel(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off, size: 64, color: BlueprintTokens.accent),
                        const SizedBox(height: 14),
                        Text(
                          'Signal lost',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: BlueprintTokens.ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No internet connection detected.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: BlueprintTokens.muted,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Turn on Wi-Fi or mobile data and try again.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: BlueprintTokens.muted,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry connection'),
                          style: FilledButton.styleFrom(
                            backgroundColor: BlueprintTokens.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
