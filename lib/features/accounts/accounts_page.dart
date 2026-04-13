import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/account_provider.dart';
import '../../state/account_selection_provider.dart';
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
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final thisMonth = DateTime.now();
    final thisMonthLabel = DateFormat('MMMM yyyy').format(thisMonth);

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
                        label: thisMonthLabel,
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
                        value: accountProvider.accounts
                            .where(
                              (account) =>
                                  subscriptionProvider
                                      .subscriptionForAccountInMonth(
                                        accountDocId: account.id,
                                        month: thisMonth,
                                      )
                                      ?.isPaid ==
                                  true,
                            )
                            .length
                            .toString(),
                      ),
                      _MetricChip(
                        label: 'Unpaid',
                        value: accountProvider.accounts
                            .where(
                              (account) =>
                                  subscriptionProvider
                                      .subscriptionForAccountInMonth(
                                        accountDocId: account.id,
                                        month: thisMonth,
                                      )
                                      ?.isPaid !=
                                  true,
                            )
                            .length
                            .toString(),
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
                            .subscriptionForAccountInMonth(
                              accountDocId: account.id,
                              month: thisMonth,
                            );
                        final isSelected =
                            selectionProvider.accountId == account.id;
                        final surface = Theme.of(context).colorScheme.surface;

                        return ListTile(
                          tileColor: surface.withValues(alpha: 0.85),
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.business,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            account.businessName.isEmpty
                                ? 'Unnamed account'
                                : account.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Owner: ${account.ownerName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PaidBadge(isPaid: subscription?.isPaid == true),
                              const SizedBox(height: 4),
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
