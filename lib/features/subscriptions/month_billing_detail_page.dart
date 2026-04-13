import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/subscription_provider.dart';
import '../accounts/subscription_management_panel.dart';

class MonthBillingDetailPage extends StatefulWidget {
  const MonthBillingDetailPage({super.key, required this.month});

  final DateTime month;

  @override
  State<MonthBillingDetailPage> createState() => _MonthBillingDetailPageState();
}

class _MonthBillingDetailPageState extends State<MonthBillingDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<SubscriptionProvider>().setMonth(widget.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Billing ${DateFormat('MMMM yyyy').format(widget.month)}'),
      ),
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
              Text(
                'Month Statistics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStat(
                    label: 'Accounts',
                    value: provider.entries.length.toString(),
                  ),
                  _MiniStat(
                    label: 'Paid',
                    value: provider.paidCount.toString(),
                  ),
                  _MiniStat(
                    label: 'Unpaid',
                    value: provider.unpaidCount.toString(),
                  ),
                  _MiniStat(
                    label: 'Collected',
                    value: provider.totalCollected.toStringAsFixed(2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SubscriptionManagementPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}
