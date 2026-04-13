import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/subscription_management_panel.dart';
import '../../state/subscription_provider.dart';

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final groups = provider.billingMonthGroups;

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
            Text(
              'Billing by Month',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Select a month first, then review full billed account details below.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (groups.isEmpty)
              const Text('No month groups found yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groups.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final isSelected = group.monthKey == provider.currentMonthKey;

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12)
                        : Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.85),
                    leading: Icon(
                      Icons.calendar_month,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(group.label),
                    subtitle: Text(
                      '${group.total} accounts • ${group.paid} paid • ${group.unpaid} unpaid',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    selected: isSelected,
                    onTap: () => provider.setMonth(group.month),
                  );
                },
              ),
            const SizedBox(height: 16),
            const SubscriptionManagementPanel(),
          ],
        ),
      ),
    );
  }
}
