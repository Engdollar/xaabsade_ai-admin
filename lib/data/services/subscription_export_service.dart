import 'subscription_export_service_stub.dart'
    if (dart.library.io) 'subscription_export_service_io.dart'
    if (dart.library.html) 'subscription_export_service_web.dart';

class SubscriptionExportRow {
  const SubscriptionExportRow({
    required this.accountId,
    required this.businessName,
    required this.ownerName,
    required this.statusLabel,
    required this.amount,
    required this.notes,
    required this.paidAtLabel,
  });

  final String accountId;
  final String businessName;
  final String ownerName;
  final String statusLabel;
  final double amount;
  final String notes;
  final String paidAtLabel;
}

class SubscriptionExportResult {
  const SubscriptionExportResult({
    required this.filePath,
    required this.fileName,
  });

  final String filePath;
  final String fileName;
}

abstract class SubscriptionExportService {
  Future<SubscriptionExportResult> exportMonthlyReport({
    required DateTime month,
    required List<SubscriptionExportRow> rows,
  });
}

SubscriptionExportService createSubscriptionExportService() {
  return createSubscriptionExportServiceImpl();
}
