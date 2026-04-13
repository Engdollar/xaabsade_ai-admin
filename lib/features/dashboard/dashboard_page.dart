import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/account.dart';
import '../../data/models/device.dart';
import '../../state/account_provider.dart';
import '../../state/account_selection_provider.dart';
import '../../state/device_provider.dart';
import '../../widgets/glass_panel.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final selectionProvider = context.watch<AccountSelectionProvider>();

    final hasSelection = accountProvider.accounts.any(
      (account) => account.id == selectionProvider.accountId,
    );
    if (accountProvider.accounts.isNotEmpty && !hasSelection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final stillMissing = accountProvider.accounts.every(
          (account) => account.id != selectionProvider.accountId,
        );
        if (stillMissing) {
          selectionProvider.select(accountProvider.accounts.first.id);
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F2EA), Color(0xFFDDE9E6), Color(0xFFF9EFE1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _DashboardHeader(onSignOut: _signOut),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 920;
                    if (isWide) {
                      return Row(
                        children: [
                          SizedBox(
                            width: 360,
                            child: _AccountsPanel(provider: accountProvider),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _AccountDetailPanel(
                              accountProvider: accountProvider,
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      children: [
                        _AccountsPanel(provider: accountProvider),
                        const SizedBox(height: 16),
                        _AccountDetailPanel(accountProvider: accountProvider),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accounts & Devices',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Review access, device status, and account metadata.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _AccountsPanel extends StatelessWidget {
  const _AccountsPanel({required this.provider});

  final AccountProvider provider;

  @override
  Widget build(BuildContext context) {
    final selectionProvider = context.watch<AccountSelectionProvider>();

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              _StatusChip(label: provider.accounts.length.toString()),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.isLoading)
            const Center(child: CircularProgressIndicator()),
          if (provider.errorMessage != null)
            Text(provider.errorMessage!, style: _errorStyle(context)),
          if (!provider.isLoading && provider.accounts.isEmpty)
            const Text('No accounts found.'),
          if (provider.accounts.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final account = provider.accounts[index];
                final isSelected = selectionProvider.accountId == account.id;
                return _AccountTile(
                  account: account,
                  isSelected: isSelected,
                  onTap: () => selectionProvider.select(account.id),
                  onEdit: () => _showEditAccountDialog(context, account),
                  onDelete: () => _confirmDeleteAccount(context, account),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: provider.accounts.length,
            ),
        ],
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
        'businessName': businessController.text.trim(),
        'ownerName': ownerController.text.trim(),
        'activeDeviceId': activeDeviceController.text.trim(),
        'allowedDeviceIds': allowedDevices,
      });
    }
  }
}

class _AccountDetailPanel extends StatelessWidget {
  const _AccountDetailPanel({required this.accountProvider});

  final AccountProvider accountProvider;

  @override
  Widget build(BuildContext context) {
    final selectionProvider = context.watch<AccountSelectionProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final currentUser = FirebaseAuth.instance.currentUser;

    Account? selectedAccount;
    for (final account in accountProvider.accounts) {
      if (account.id == selectionProvider.accountId) {
        selectedAccount = account;
        break;
      }
    }

    if (selectedAccount == null) {
      return GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text('Select an account to view device data.'),
          ],
        ),
      );
    }

    Device? activeDevice;
    for (final device in deviceProvider.devices) {
      if (device.deviceId == selectedAccount.activeDeviceId) {
        activeDevice = device;
        break;
      }
    }
    final allowedDeviceIds = deviceProvider.devices
        .where((device) => device.allowed)
        .map((device) => device.deviceId)
        .toList();

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthUserPanel(
            email: currentUser?.email ?? 'unknown',
            onUpdateEmail: () => _showUpdateEmailDialog(context, currentUser),
            onUpdatePassword: () =>
                _showUpdatePasswordDialog(context, currentUser),
            onDelete: () => _confirmDeleteAuthUser(context, currentUser),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedAccount.businessName.isEmpty
                          ? 'Unnamed account'
                          : selectedAccount.businessName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner: ${selectedAccount.ownerName}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _StatusChip(label: selectedAccount.accountId),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoPill(
                label: 'Active device',
                value: activeDevice == null
                    ? selectedAccount.activeDeviceId
                    : '${activeDevice.deviceId} • ${activeDevice.deviceName}',
              ),
              _InfoPill(
                label: 'Last seen',
                value: _formatDate(selectedAccount.lastSeenAt),
              ),
              _InfoPill(
                label: 'Updated',
                value: _formatDate(selectedAccount.updatedAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Allowed devices',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (allowedDeviceIds.isEmpty)
            const Text('No allowed devices listed.'),
          if (allowedDeviceIds.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allowedDeviceIds
                  .map((deviceId) => _StatusChip(label: deviceId))
                  .toList(),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Devices', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              _StatusChip(label: deviceProvider.devices.length.toString()),
            ],
          ),
          const SizedBox(height: 12),
          if (deviceProvider.isLoading)
            const Center(child: CircularProgressIndicator()),
          if (deviceProvider.errorMessage != null)
            Text(deviceProvider.errorMessage!, style: _errorStyle(context)),
          if (!deviceProvider.isLoading && deviceProvider.devices.isEmpty)
            const Text('No devices for this account.'),
          if (deviceProvider.devices.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final device = deviceProvider.devices[index];
                return _DeviceTile(
                  device: device,
                  onEdit: () => _showEditDeviceDialog(context, device),
                  onDelete: () => _confirmDeleteDevice(context, device),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: deviceProvider.devices.length,
            ),
        ],
      ),
    );
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
    final nameController = TextEditingController(text: device.deviceName);
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
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
                  ],
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
        'deviceName': nameController.text.trim(),
        'allowed': allowed,
      });
    }
  }

  Future<void> _showUpdateEmailDialog(BuildContext context, User? user) async {
    if (user == null || user.email == null) {
      _showError(context, 'No signed-in user found.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: user.email);
    final passwordController = TextEditingController();

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update email'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'New email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required.';
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required.';
                    }
                    return null;
                  },
                ),
              ],
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
      await _reauthenticate(user, passwordController.text.trim(), context);
      try {
        await user.updateEmail(emailController.text.trim());
      } on FirebaseAuthException catch (error) {
        _showError(context, error.message ?? 'Failed to update email.');
      }
    }
  }

  Future<void> _showUpdatePasswordDialog(
    BuildContext context,
    User? user,
  ) async {
    if (user == null || user.email == null) {
      _showError(context, 'No signed-in user found.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final newPasswordController = TextEditingController();

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'New password is required.';
                    }
                    if (value.length < 6) {
                      return 'Use at least 6 characters.';
                    }
                    return null;
                  },
                ),
              ],
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
      await _reauthenticate(user, passwordController.text.trim(), context);
      try {
        await user.updatePassword(newPasswordController.text.trim());
      } on FirebaseAuthException catch (error) {
        _showError(context, error.message ?? 'Failed to update password.');
      }
    }
  }

  Future<void> _confirmDeleteAuthUser(BuildContext context, User? user) async {
    if (user == null || user.email == null) {
      _showError(context, 'No signed-in user found.');
      return;
    }

    final passwordController = TextEditingController();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete login account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This removes the authentication account and signs you out.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
            ],
          ),
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
      await _reauthenticate(user, passwordController.text.trim(), context);
      try {
        await user.delete();
      } on FirebaseAuthException catch (error) {
        _showError(context, error.message ?? 'Failed to delete account.');
      }
    }
  }

  Future<void> _reauthenticate(
    User user,
    String password,
    BuildContext context,
  ) async {
    if (password.isEmpty) {
      _showError(context, 'Password is required.');
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'Password is required.',
      );
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      _showError(context, error.message ?? 'Re-authentication failed.');
      rethrow;
    }
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Account account;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1.2,
          ),
        ),
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
              ],
            ),
            const SizedBox(height: 6),
            Text('Owner: ${account.ownerName}'),
            const SizedBox(height: 4),
            Text('Active: ${account.activeDeviceId}'),
          ],
        ),
      ),
    );
  }
}

class _AuthUserPanel extends StatelessWidget {
  const _AuthUserPanel({
    required this.email,
    required this.onUpdateEmail,
    required this.onUpdatePassword,
    required this.onDelete,
  });

  final String email;
  final VoidCallback onUpdateEmail;
  final VoidCallback onUpdatePassword;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Login user', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              _StatusChip(label: email),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onUpdateEmail,
                icon: const Icon(Icons.alternate_email),
                label: const Text('Update email'),
              ),
              OutlinedButton.icon(
                onPressed: onUpdatePassword,
                icon: const Icon(Icons.key_outlined),
                label: const Text('Update password'),
              ),
              FilledButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete login'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
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
              _StatusChip(
                label: device.allowed ? 'Allowed' : 'Blocked',
                color: chipColor,
                textColor: Colors.white,
              ),
              const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 6),
          Text('Device ID: ${device.deviceId}'),
          const SizedBox(height: 4),
          Text('Platform: ${device.platform}  |  App: ${device.appName}'),
          const SizedBox(height: 4),
          Text('Last seen: ${_formatDate(device.lastSeenAt)}'),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = color ?? Colors.white.withOpacity(0.8);
    final foregroundColor = textColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foregroundColor),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

TextStyle _errorStyle(BuildContext context) {
  return Theme.of(
    context,
  ).textTheme.bodyMedium!.copyWith(color: Colors.redAccent);
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) {
    return 'N/A';
  }
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
