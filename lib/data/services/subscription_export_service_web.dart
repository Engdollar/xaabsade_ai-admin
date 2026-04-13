import 'subscription_export_service.dart';

class _WebSubscriptionExportService implements SubscriptionExportService {
  @override
  Future<SubscriptionExportResult> exportMonthlyReport({
    required DateTime month,
    required List<SubscriptionExportRow> rows,
  }) {
    throw UnsupportedError('Excel export is not supported on web yet.');
  }
}

SubscriptionExportService createSubscriptionExportServiceImpl() {
  return _WebSubscriptionExportService();
}
