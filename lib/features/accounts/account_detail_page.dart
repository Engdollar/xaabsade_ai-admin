import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/account.dart';
import '../../data/models/device.dart';
import '../../state/account_provider.dart';
import '../../state/account_selection_provider.dart';
import '../../state/device_provider.dart';
import '../../state/subscription_provider.dart';
import '../../widgets/glass_panel.dart';

class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final selectionProvider = context.watch<AccountSelectionProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();

    Account? account;
    for (final item in accountProvider.accounts) {
      if (item.id == accountId) {
        account = item;
        break;
      }
    }

    if (selectionProvider.accountId != accountId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        selectionProvider.select(accountId);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account details')),
      body: Container(
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
              if (account == null)
                const Text('Account not found.')
              else
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.businessName.isEmpty
                                  ? 'Unnamed account'
                                  : account.businessName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _showEditAccountDialog(context, account!),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            onPressed: () =>
                                _confirmDeleteAccount(context, account!),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Owner: ${account.ownerName}'),
                      const SizedBox(height: 6),
                      Text('Account ID: ${account.accountId}'),
                      const SizedBox(height: 6),
                      Text('Active device: ${account.activeDeviceId}'),
                      const SizedBox(height: 14),
                      Text(
                        'Billing quick info',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final bills = subscriptionProvider.billsForAccount(
                            account!.id,
                          );
                          if (bills.isEmpty) {
                            return const Text('No monthly bills found yet.');
                          }

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: bills.map((bill) {
                              final month = _monthLabelFromKey(bill.monthKey);
                              final paid = bill.isPaid ? 'Paid' : 'Unpaid';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('$month • $paid • ${bill.amount}'),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Devices',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (deviceProvider.isLoading)
                      const Center(child: CircularProgressIndicator()),
                    if (deviceProvider.errorMessage != null)
                      Text(deviceProvider.errorMessage!),
                    if (!deviceProvider.isLoading &&
                        deviceProvider.devices.isEmpty)
                      const Text('No devices for this account.'),
                    if (deviceProvider.devices.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: deviceProvider.devices.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final device = deviceProvider.devices[index];
                          return _DeviceTile(
                            device: device,
                            onEdit: () =>
                                _showEditDeviceDialog(context, device),
                            onDelete: () =>
                                _confirmDeleteDevice(context, device),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
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
  ) async {
    final provider = context.read<AccountProvider>();
    final formKey = GlobalKey<FormState>();
    final accountIdController = TextEditingController(text: account.accountId);
    final accountIdLowerController = TextEditingController(
      text: account.accountIdLower,
    );
    final businessController = TextEditingController(
      text: account.businessName,
    );
    final ownerController = TextEditingController(text: account.ownerName);
    final activeDeviceController = TextEditingController(
      text: account.activeDeviceId,
    );
    final allowedDevicesController = TextEditingController(
      text: account.allowedDeviceIds.join(', '),
    );

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update account'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: accountIdController,
                    decoration: const InputDecoration(labelText: 'Account ID'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Account ID is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: accountIdLowerController,
                    decoration: const InputDecoration(
                      labelText: 'Account ID (lowercase)',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Account ID (lowercase) is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
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
                    decoration: const InputDecoration(labelText: 'Owner name'),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: allowedDevicesController,
                    decoration: const InputDecoration(
                      labelText: 'Allowed device ids',
                      helperText: 'Comma-separated list',
                    ),
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

    if (shouldUpdate == true) {
      final allowedDevices = allowedDevicesController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      await provider.updateAccount(account.id, {
        'accountId': accountIdController.text.trim(),
        'accountIdLower': accountIdLowerController.text.trim(),
        'businessName': businessController.text.trim(),
        'ownerName': ownerController.text.trim(),
        'activeDeviceId': activeDeviceController.text.trim(),
        'allowedDeviceIds': allowedDevices,
      });
    }
  }

  Future<void> _confirmDeleteDevice(BuildContext context, Device device) async {
    final provider = context.read<DeviceProvider>();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete device'),
          content: Text('Delete ${device.deviceName}?'),
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
      await provider.deleteDevice(device.id);
    }
  }

  Future<void> _showEditDeviceDialog(
    BuildContext context,
    Device device,
  ) async {
    final provider = context.read<DeviceProvider>();
    final formKey = GlobalKey<FormState>();
    final accountIdController = TextEditingController(text: device.accountId);
    final deviceIdController = TextEditingController(text: device.deviceId);
    final deviceNameController = TextEditingController(text: device.deviceName);
    final appNameController = TextEditingController(text: device.appName);
    final buildNumberController = TextEditingController(
      text: device.buildNumber,
    );
    final packageNameController = TextEditingController(
      text: device.packageName,
    );
    final platformController = TextEditingController(text: device.platform);
    final versionController = TextEditingController(text: device.version);
    bool allowed = device.allowed;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update device'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: accountIdController,
                        decoration: const InputDecoration(
                          labelText: 'Account ID',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Account ID is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deviceIdController,
                        decoration: const InputDecoration(
                          labelText: 'Device ID',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Device ID is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deviceNameController,
                        decoration: const InputDecoration(
                          labelText: 'Device name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Device name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: allowed,
                        onChanged: (value) => setState(() => allowed = value),
                        title: const Text('Allowed'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: appNameController,
                        decoration: const InputDecoration(
                          labelText: 'App name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: buildNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Build number',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: packageNameController,
                        decoration: const InputDecoration(
                          labelText: 'Package name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: platformController,
                        decoration: const InputDecoration(
                          labelText: 'Platform',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: versionController,
                        decoration: const InputDecoration(labelText: 'Version'),
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
      await provider.updateDevice(device.id, {
        'accountId': accountIdController.text.trim(),
        'deviceId': deviceIdController.text.trim(),
        'deviceName': deviceNameController.text.trim(),
        'allowed': allowed,
        'appName': appNameController.text.trim(),
        'buildNumber': buildNumberController.text.trim(),
        'packageName': packageNameController.text.trim(),
        'platform': platformController.text.trim(),
        'version': versionController.text.trim(),
      });
    }
  }
}

String _monthLabelFromKey(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) {
    return monthKey;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return monthKey;
  }
  return DateFormat('MMMM yyyy').format(DateTime(year, month));
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onEdit,
    required this.onDelete,
  });

  final Device device;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final chipColor = device.allowed
        ? const Color(0xFF0E6B67)
        : const Color(0xFFB23A48);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  device.deviceName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  device.allowed ? 'Allowed' : 'Blocked',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Device ID: ${device.deviceId}'),
          const SizedBox(height: 4),
          Text('Platform: ${device.platform}  |  App: ${device.appName}'),
        ],
      ),
    );
  }
}
