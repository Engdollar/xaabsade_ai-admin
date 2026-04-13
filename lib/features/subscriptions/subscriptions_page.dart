import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/subscription_provider.dart';
import 'month_billing_detail_page.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: provider.isInitializing
                      ? null
                      : _openGenerateMonthSheet,
                  icon: provider.isInitializing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add_check_circle_outlined),
                  label: const Text('Generate Month Billing'),
                ),
                FilledButton.tonalIcon(
                  onPressed: provider.isExporting ? null : _openExportSheet,
                  icon: provider.isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  label: const Text('Export Excel'),
                ),
                OutlinedButton.icon(
                  onPressed: _openDeleteMonthSheet,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Month Bills'),
                ),
              ],
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
                    onTap: () {
                      provider.setMonth(group.month);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MonthBillingDetailPage(month: group.month),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDeleteMonthSheet() async {
    final provider = context.read<SubscriptionProvider>();
    var selectedMonth = provider.currentMonth;

    final shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Month Bills',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will delete all bill records for the selected month.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Month to delete'),
                    subtitle: Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final picked = await _pickMonth(selectedMonth);
                      if (picked == null) {
                        return;
                      }
                      setState(() {
                        selectedMonth = picked;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete all'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldSubmit != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm delete'),
          content: Text(
            'Delete all bills for ${DateFormat('MMMM yyyy').format(selectedMonth)}?',
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

    if (confirm != true) {
      return;
    }

    try {
      await provider.deleteMonthBills(selectedMonth);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted bills for ${DateFormat('MMMM yyyy').format(selectedMonth)}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete month bills.')),
      );
    }
  }

  Future<void> _openGenerateMonthSheet() async {
    final provider = context.read<SubscriptionProvider>();
    var selectedMonth = provider.currentMonth;
    final amountController = TextEditingController(text: '0');

    final shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate Month Billing',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create billing records for all accounts in the selected month.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Billing month'),
                    subtitle: Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final picked = await _pickMonth(selectedMonth);
                      if (picked == null) {
                        return;
                      }
                      setState(() {
                        selectedMonth = picked;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Default amount per account',
                      helperText: 'Used for newly created records only.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Generate'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldSubmit != true) {
      return;
    }

    final amount = double.tryParse(amountController.text.trim()) ?? 0;

    try {
      await provider.initializeMonth(
        month: selectedMonth,
        defaultAmount: amount,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Billing records generated for ${DateFormat('MMMM yyyy').format(selectedMonth)}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not generate month billing.')),
      );
    }
  }

  Future<void> _openExportSheet() async {
    final provider = context.read<SubscriptionProvider>();
    var selectedMonth = provider.currentMonth;
    var scope = SubscriptionExportScope.all;

    final shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Billing Excel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose month and status scope for export.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Export month'),
                    subtitle: Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final picked = await _pickMonth(selectedMonth);
                      if (picked == null) {
                        return;
                      }
                      setState(() {
                        selectedMonth = picked;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SubscriptionExportScope>(
                    initialValue: scope,
                    decoration: const InputDecoration(
                      labelText: 'Status scope',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SubscriptionExportScope.all,
                        child: Text('All (paid + unpaid)'),
                      ),
                      DropdownMenuItem(
                        value: SubscriptionExportScope.paid,
                        child: Text('Paid only'),
                      ),
                      DropdownMenuItem(
                        value: SubscriptionExportScope.unpaid,
                        child: Text('Unpaid only'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        scope = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Export'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldSubmit != true) {
      return;
    }

    try {
      final result = await provider.exportMonth(
        month: selectedMonth,
        scope: scope,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel exported to ${result.filePath}')),
      );
    } on UnsupportedError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Export is not supported.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export billing report.')),
      );
    }
  }

  Future<DateTime?> _pickMonth(DateTime initialMonth) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initialMonth.year, initialMonth.month, 1),
      firstDate: DateTime(now.year - 6, 1, 1),
      lastDate: DateTime(now.year + 6, 12, 31),
      helpText: 'Select billing month',
    );
    if (picked == null) {
      return null;
    }
    return DateTime(picked.year, picked.month);
  }
}
