import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/account.dart';
import '../../state/account_provider.dart';
import '../../state/account_selection_provider.dart';
import '../../state/device_provider.dart';
import '../../state/subscription_provider.dart';
import '../../widgets/glass_panel.dart';
import 'account_detail_page.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final selectionProvider = context.watch<AccountSelectionProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();

    final filteredAccounts = accountProvider.accounts.where((account) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return account.businessName.toLowerCase().contains(query) ||
          account.ownerName.toLowerCase().contains(query) ||
          account.accountId.toLowerCase().contains(query);
    }).toList();

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
            TextField(
              onChanged: (value) => setState(() {
                _searchQuery = value;
              }),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search account, owner, or account ID',
              ),
            ),
            const SizedBox(height: 12),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accounts Directory',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select, update, and audit account-level billing visibility.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      _StatusTag(
                        label: subscriptionProvider.currentMonthLabel,
                        icon: Icons.calendar_month,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricChip(
                        label: 'Total',
                        value: accountProvider.accounts.length.toString(),
                      ),
                      _MetricChip(
                        label: 'Filtered',
                        value: filteredAccounts.length.toString(),
                      ),
                      _MetricChip(
                        label: 'Paid',
                        value: subscriptionProvider.paidCount.toString(),
                      ),
                      _MetricChip(
                        label: 'Unpaid',
                        value: subscriptionProvider.unpaidCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (accountProvider.isLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (accountProvider.errorMessage != null)
                    Text(accountProvider.errorMessage!),
                  if (!accountProvider.isLoading &&
                      accountProvider.accounts.isEmpty)
                    const Text('No accounts found.'),
                  if (!accountProvider.isLoading &&
                      accountProvider.accounts.isNotEmpty &&
                      filteredAccounts.isEmpty)
                    const Text('No account matches your search.'),
                  if (filteredAccounts.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredAccounts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final account = filteredAccounts[index];
                        final subscription = subscriptionProvider
                            .subscriptionForAccount(account.id);
                        final isSelected =
                            selectionProvider.accountId == account.id;
                        final surface = Theme.of(context).colorScheme.surface;

                        return ListTile(
                          tileColor: surface.withValues(alpha: 0.85),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            account.businessName.isEmpty
                                ? 'Unnamed account'
                                : account.businessName,
                          ),
                          subtitle: Text(
                            'Owner: ${account.ownerName} • ${subscription?.isPaid == true ? 'Paid' : 'Unpaid'}',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              _PaidBadge(isPaid: subscription?.isPaid == true),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit',
                                onPressed: () {
                                  selectionProvider.select(account.id);
                                  _showEditAccountDialog(
                                    context,
                                    account,
                                    deviceProvider,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete',
                                onPressed: () =>
                                    _confirmDeleteAccount(context, account),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          selected: isSelected,
                          onTap: () {
                            selectionProvider.select(account.id);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    AccountDetailPage(accountId: account.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    Account account,
  ) async {
    final provider = context.read<AccountProvider>();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account'),
          content: Text('Delete ${account.businessName} and its data?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await provider.deleteAccount(account.id);
    }
  }

  Future<void> _showEditAccountDialog(
    BuildContext context,
    Account account,
    DeviceProvider deviceProvider,
  ) async {
    final provider = context.read<AccountProvider>();
    final formKey = GlobalKey<FormState>();
    final businessController = TextEditingController(
      text: account.businessName,
    );
    final ownerController = TextEditingController(text: account.ownerName);
    final activeDeviceController = TextEditingController(
      text: account.activeDeviceId,
    );
    final devices = deviceProvider.devices;
    final allowedDevices = account.allowedDeviceIds.toSet();
    for (final device in devices) {
      if (device.allowed) {
        allowedDevices.add(device.deviceId);
      }
    }

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update account'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: businessController,
                        decoration: const InputDecoration(
                          labelText: 'Business name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Business name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerController,
                        decoration: const InputDecoration(
                          labelText: 'Owner name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Owner name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: activeDeviceController,
                        decoration: const InputDecoration(
                          labelText: 'Active device id',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Allowed devices',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (deviceProvider.isLoading)
                        const Center(child: CircularProgressIndicator()),
                      if (!deviceProvider.isLoading && devices.isEmpty)
                        const Text('No devices loaded for this account.'),
                      if (devices.isNotEmpty)
                        Column(
                          children: devices.map((device) {
                            final isAllowed = allowedDevices.contains(
                              device.deviceId,
                            );
                            return SwitchListTile.adaptive(
                              value: isAllowed,
                              onChanged: (value) async {
                                setState(() {
                                  if (value) {
                                    allowedDevices.add(device.deviceId);
                                  } else {
                                    allowedDevices.remove(device.deviceId);
                                  }
                                });
                                await deviceProvider.updateDevice(device.id, {
                                  'allowed': value,
                                });
                              },
                              title: Text(device.deviceName),
                              subtitle: Text(device.deviceId),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldUpdate == true) {
      await provider.updateAccount(account.id, {
        'businessName': businessController.text.trim(),
        'ownerName': ownerController.text.trim(),
        'activeDeviceId': activeDeviceController.text.trim(),
        'allowedDeviceIds': allowedDevices.toList(),
      });
    }
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  const _PaidBadge({required this.isPaid});

  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final background = isPaid
        ? Colors.green.withValues(alpha: 0.12)
        : Colors.orange.withValues(alpha: 0.12);
    final foreground = isPaid ? Colors.green.shade700 : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Unpaid',
        style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}
