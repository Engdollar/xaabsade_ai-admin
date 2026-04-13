import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/account_provider.dart';
import '../../state/account_selection_provider.dart';
import '../../widgets/glass_panel.dart';
import '../accounts/account_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final selectionProvider = context.watch<AccountSelectionProvider>();
    final query = _controller.text.trim().toLowerCase();

    final filtered = accountProvider.accounts.where((account) {
      if (query.isEmpty) {
        return false;
      }
      final businessName = account.businessName.toLowerCase();
      return account.accountIdLower.contains(query) ||
          account.accountId.contains(query) ||
          businessName.contains(query);
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
            Text('Search', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Search by account ID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (query.isEmpty)
                    const Text('Type an account ID to search.'),
                  if (query.isNotEmpty && filtered.isEmpty)
                    const Text('No accounts match that query.'),
                  if (filtered.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final account = filtered[index];
                        final surface = Theme.of(context).colorScheme.surface;
                        return ListTile(
                          tileColor: surface.withOpacity(0.85),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            account.businessName.isEmpty
                                ? 'Unnamed account'
                                : account.businessName,
                          ),
                          subtitle: Text('Account ID: ${account.accountId}'),
                          trailing: const Icon(Icons.chevron_right),
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
}
