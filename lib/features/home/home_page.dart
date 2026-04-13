import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/account_provider.dart';
import '../../state/device_provider.dart';
import '../../state/subscription_provider.dart';
import '../../widgets/glass_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();

    final totalAccounts = accountProvider.accounts.length;
    final totalDevices = deviceProvider.devices.length;
    final allowedDevices = deviceProvider.devices
        .where((device) => device.allowed)
        .length;
    final paidAccounts = subscriptionProvider.paidCount;
    final unpaidAccounts = subscriptionProvider.unpaidCount;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F2EA), Color(0xFFDDE9E6), Color(0xFFF9EFE1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Quick stats for the selected account and devices.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Totals', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        label: 'Accounts',
                        value: totalAccounts.toString(),
                        icon: Icons.business,
                      ),
                      _StatCard(
                        label: 'Devices',
                        value: totalDevices.toString(),
                        icon: Icons.devices,
                      ),
                      _StatCard(
                        label: 'Allowed',
                        value: allowedDevices.toString(),
                        icon: Icons.verified_user,
                      ),
                      _StatCard(
                        label: 'Paid',
                        value: paidAccounts.toString(),
                        icon: Icons.check_circle_outline,
                      ),
                      _StatCard(
                        label: 'Not paid',
                        value: unpaidAccounts.toString(),
                        icon: Icons.error_outline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Subscription snapshot for ${subscriptionProvider.currentMonthLabel}: '
                    '$paidAccounts paid and $unpaidAccounts not paid.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}
