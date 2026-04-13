import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'subscription_export_service.dart';

class _IoSubscriptionExportService implements SubscriptionExportService {
  @override
  Future<SubscriptionExportResult> exportMonthlyReport({
    required DateTime month,
    required List<SubscriptionExportRow> rows,
  }) async {
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    final sheetName = 'Subscriptions';
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.rename(defaultSheet, sheetName);
    }
    final sheet = workbook[sheetName];

    sheet.appendRow(<CellValue>[
      TextCellValue('Month'),
      TextCellValue('Account ID'),
      TextCellValue('Business name'),
      TextCellValue('Owner name'),
      TextCellValue('Status'),
      TextCellValue('Amount'),
      TextCellValue('Paid at'),
      TextCellValue('Notes'),
    ]);

    final monthLabel = DateFormat('MMMM yyyy').format(month);
    for (final row in rows) {
      sheet.appendRow(<CellValue>[
        TextCellValue(monthLabel),
        TextCellValue(row.accountId),
        TextCellValue(row.businessName),
        TextCellValue(row.ownerName),
        TextCellValue(row.statusLabel),
        DoubleCellValue(row.amount),
        TextCellValue(row.paidAtLabel),
        TextCellValue(row.notes),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw const FileSystemException('Failed to encode Excel workbook.');
    }

    final directory = await _resolveExportDirectory();
    final fileName =
        'subscriptions_${DateFormat('yyyy_MM').format(month)}.xlsx';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return SubscriptionExportResult(filePath: file.path, fileName: fileName);
  }

  Future<Directory> _resolveExportDirectory() async {
    if (Platform.isIOS) {
      // iOS apps are sandboxed and cannot write directly to a public Downloads folder.
      final documentsDirectory = await getApplicationDocumentsDirectory();
      await documentsDirectory.create(recursive: true);
      return documentsDirectory;
    }

    final publicDownloads = await _resolvePublicDownloadsDirectory();
    if (publicDownloads != null) {
      return publicDownloads;
    }

    final downloadsDirectory = await getDownloadsDirectory();
    if (downloadsDirectory != null) {
      await downloadsDirectory.create(recursive: true);
      return downloadsDirectory;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    await documentsDirectory.create(recursive: true);
    return documentsDirectory;
  }

  Future<Directory?> _resolvePublicDownloadsDirectory() async {
    final candidates = <Directory>[];

    if (Platform.isAndroid) {
      candidates.add(Directory('/storage/emulated/0/Download'));
      candidates.add(Directory('/sdcard/Download'));
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        candidates.add(Directory('$userProfile/Downloads'));
      }
    }

    for (final directory in candidates) {
      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      } catch (_) {
        // Keep trying other candidates or fall back to app-specific storage.
      }
    }

    return null;
  }
}

SubscriptionExportService createSubscriptionExportServiceImpl() {
  return _IoSubscriptionExportService();
}
