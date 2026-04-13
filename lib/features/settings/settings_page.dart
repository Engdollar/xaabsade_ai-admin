import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/theme_provider.dart';
import '../../widgets/glass_panel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = context.watch<ThemeProvider>();

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
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Email: ${user?.email ?? 'unknown'}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showUpdateEmailDialog(context, user),
                        icon: const Icon(Icons.alternate_email),
                        label: const Text('Update email'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showUpdatePasswordDialog(context, user),
                        icon: const Icon(Icons.key_outlined),
                        label: const Text('Update password'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _confirmDeleteAuthUser(context, user),
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete login'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: themeProvider.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setThemeMode(value);
                      }
                    },
                    title: const Text('System'),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: themeProvider.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setThemeMode(value);
                      }
                    },
                    title: const Text('Light'),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: themeProvider.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setThemeMode(value);
                      }
                    },
                    title: const Text('Dark'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
