import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/subscription_provider.dart';
import '../../widgets/glass_panel.dart';

enum _SubscriptionFilter { all, paid, unpaid }

class SubscriptionManagementPanel extends StatefulWidget {
  const SubscriptionManagementPanel({super.key});

  @override
  State<SubscriptionManagementPanel> createState() =>
      _SubscriptionManagementPanelState();
}

class _SubscriptionManagementPanelState
    extends State<SubscriptionManagementPanel> {
  final NumberFormat _amountFormat = NumberFormat('#,##0.##');
  String _searchQuery = '';
  _SubscriptionFilter _filter = _SubscriptionFilter.all;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final entries = provider.entries.where(_matchesEntry).toList();

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) => setState(() {
              _searchQuery = value;
            }),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search billed account, owner, or account ID',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Billed Accounts Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Detailed account billing records for ${provider.currentMonthLabel}.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _MonthBadge(label: provider.currentMonthLabel),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryCard(
                label: 'Accounts',
                value: provider.entries.length.toString(),
                icon: Icons.business_outlined,
              ),
              _SummaryCard(
                label: 'Paid',
                value: provider.paidCount.toString(),
                icon: Icons.check_circle_outline,
              ),
              _SummaryCard(
                label: 'Unpaid',
                value: provider.unpaidCount.toString(),
                icon: Icons.error_outline,
              ),
              _SummaryCard(
                label: 'Collected',
                value: _amountFormat.format(provider.totalCollected),
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == _SubscriptionFilter.all,
                onSelected: (_) => setState(() {
                  _filter = _SubscriptionFilter.all;
                }),
              ),
              ChoiceChip(
                label: const Text('Paid'),
                selected: _filter == _SubscriptionFilter.paid,
                onSelected: (_) => setState(() {
                  _filter = _SubscriptionFilter.paid;
                }),
              ),
              ChoiceChip(
                label: const Text('Unpaid'),
                selected: _filter == _SubscriptionFilter.unpaid,
                onSelected: (_) => setState(() {
                  _filter = _SubscriptionFilter.unpaid;
                }),
              ),
            ],
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          if (provider.isLoading && provider.entries.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (!provider.isLoading && provider.entries.isEmpty)
            const Text('No accounts available for billing tracking.'),
          if (!provider.isLoading &&
              provider.entries.isNotEmpty &&
              entries.isEmpty)
            const Text('No accounts match the search and filter.'),
          if (entries.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _SubscriptionEntryCard(
                  entry: entry,
                  amountFormat: _amountFormat,
                  onTogglePaid: () => _togglePaid(entry),
                  onEdit: () => _showEditDialog(entry),
                  onDeleteBill: () => _deleteBill(entry),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: entries.length,
            ),
        ],
      ),
    );
  }

  bool _matchesEntry(SubscriptionViewEntry entry) {
    final query = _searchQuery.trim().toLowerCase();
    final matchesFilter = switch (_filter) {
      _SubscriptionFilter.all => true,
      _SubscriptionFilter.paid => entry.isPaid,
      _SubscriptionFilter.unpaid => !entry.isPaid,
    };
    if (!matchesFilter) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    return entry.businessName.toLowerCase().contains(query) ||
        entry.account.ownerName.toLowerCase().contains(query) ||
        entry.account.accountId.toLowerCase().contains(query);
  }

  Future<void> _togglePaid(SubscriptionViewEntry entry) async {
    try {
      await context.read<SubscriptionProvider>().saveSubscription(
        account: entry.account,
        isPaid: !entry.isPaid,
        amount: entry.amount,
        notes: entry.notes,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${entry.businessName} marked as ${entry.isPaid ? 'unpaid' : 'paid'}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update billing status.')),
      );
    }
  }

  Future<void> _showEditDialog(SubscriptionViewEntry entry) async {
    final provider = context.read<SubscriptionProvider>();
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: entry.amount == 0 ? '' : entry.amount.toString(),
    );
    final notesController = TextEditingController(text: entry.notes);
    var isPaid = entry.isPaid;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Billing for ${entry.businessName}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isPaid,
                        onChanged: (value) {
                          setState(() {
                            isPaid = value;
                          });
                        },
                        title: const Text('Paid this month'),
                        subtitle: Text(entry.account.accountId),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount collected',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final amount = double.tryParse(value.trim());
                          if (amount == null || amount < 0) {
                            return 'Enter a valid amount.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText:
                              'Reference number, collector note, or follow-up.',
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
      },
    );

    if (shouldSave != true) {
      return;
    }

    try {
      await provider.saveSubscription(
        account: entry.account,
        isPaid: isPaid,
        amount: double.tryParse(amountController.text.trim()) ?? 0,
        notes: notesController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Billing updated.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save billing changes.')),
      );
    }
  }

  Future<void> _deleteBill(SubscriptionViewEntry entry) async {
    final provider = context.read<SubscriptionProvider>();
    final monthLabel = provider.currentMonthLabel;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account bill'),
          content: Text('Delete ${entry.businessName} bill for $monthLabel?'),
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

    if (shouldDelete != true) {
      return;
    }

    try {
      await provider.deleteAccountBillForCurrentMonth(entry.account.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account bill deleted.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete account bill.')),
      );
    }
  }
}

class _SubscriptionEntryCard extends StatelessWidget {
  const _SubscriptionEntryCard({
    required this.entry,
    required this.amountFormat,
    required this.onTogglePaid,
    required this.onEdit,
    required this.onDeleteBill,
  });

  final SubscriptionViewEntry entry;
  final NumberFormat amountFormat;
  final VoidCallback onTogglePaid;
  final VoidCallback onEdit;
  final VoidCallback onDeleteBill;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final paidAtLabel = entry.paidAt == null
        ? 'No payment recorded'
        : 'Paid ${DateFormat('yyyy-MM-dd').format(entry.paidAt!)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner: ${entry.account.ownerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Account ID: ${entry.account.accountId}'),
                  ],
                ),
              ),
              _PaidBadge(isPaid: entry.isPaid),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoTag(label: paidAtLabel),
              _InfoTag(label: 'Amount ${amountFormat.format(entry.amount)}'),
              if (entry.notes.trim().isNotEmpty)
                _InfoTag(label: entry.notes.trim()),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onTogglePaid,
                icon: Icon(
                  entry.isPaid
                      ? Icons.remove_circle_outline
                      : Icons.check_circle_outline,
                ),
                label: Text(entry.isPaid ? 'Mark unpaid' : 'Mark paid'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit details'),
              ),
              OutlinedButton.icon(
                onPressed: onDeleteBill,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete bill'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
      width: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBadge extends StatelessWidget {
  const _MonthBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
