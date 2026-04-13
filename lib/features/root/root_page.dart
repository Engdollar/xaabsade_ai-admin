import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/theme_provider.dart';
import '../accounts/accounts_page.dart';
import '../home/home_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import '../subscriptions/subscriptions_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  final List<_NavItem> _items = const [
    _NavItem('Home', Icons.dashboard, HomePage()),
    _NavItem('Accounts', Icons.business, AccountsPage()),
    _NavItem('Billing', Icons.receipt_long, SubscriptionsPage()),
    _NavItem('Search', Icons.search, SearchPage()),
    _NavItem('Settings', Icons.settings, SettingsPage()),
  ];

  void _selectIndex(int index) {
    if (_index == index) {
      return;
    }
    setState(() {
      _index = index;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _items[_index];

    return Scaffold(
      appBar: AppBar(title: Text(selected.label)),
      drawer: _AppDrawer(
        items: _items,
        currentIndex: _index,
        onSelect: (index) {
          Navigator.of(context).pop();
          _selectIndex(index);
        },
        onSignOut: _signOut,
      ),
      body: selected.page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectIndex,
        destinations: _items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.page);

  final String label;
  final IconData icon;
  final Widget page;
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onSignOut,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'X-ADMIN',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < items.length; i++)
                    ListTile(
                      leading: Icon(items[i].icon),
                      title: Text(items[i].label),
                      selected: currentIndex == i,
                      onTap: () => onSelect(i),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('Theme'),
                  ),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
