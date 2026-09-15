import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ai_companion/models/wallet_transaction.dart';
import 'package:ai_companion/core/services/wallet_storage_service.dart';

/// Builds the wallet Excel workbook and hands it off to the
/// platform share sheet (which the user can use to save to Files,
/// Google Drive, email, etc.).
class WalletExportService {
  WalletExportService._();

  /// Exports all wallet transactions as an `.xlsx` file and opens
  /// the native share sheet so the user picks where to save it.
  static Future<String> exportAndShare() async {
    final transactions =
        await WalletStorageService.loadTransactions();

    if (transactions.isEmpty) {
      throw Exception('No transactions to export.');
    }

    final excel = _buildWorkbook(transactions);

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file.');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'Aicompanion_Wallet_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
    final file = File('${tempDir.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: 'Aicompanion Wallet Export',
      text: 'Wallet transactions exported from Aicompanion.',
    );

    return file.path;
  }

  static Excel _buildWorkbook(
    List<WalletTransaction> transactions,
  ) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    // Rename "Sheet1" -> "Transactions".
    if (defaultSheet != null) {
      excel.rename(defaultSheet, 'Transactions');
    }

    final sheet = excel['Transactions'];

    // Header row.
    sheet.appendRow(<CellValue>[
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Description'),
      TextCellValue('Amount'),
      TextCellValue('Balance'),
    ]);

    // Oldest -> newest so the running balance reads naturally.
    final sorted = List<WalletTransaction>.from(transactions)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    var runningBalance = 0;

    for (final tx in sorted) {
      runningBalance += tx.signedAmount;

      sheet.appendRow(<CellValue>[
        TextCellValue(
          DateFormat('dd/MM/yyyy').format(tx.dateTime),
        ),
        TextCellValue(
          DateFormat('HH:mm').format(tx.dateTime),
        ),
        TextCellValue(tx.isIncome ? 'Income' : 'Expense'),
        TextCellValue(tx.category),
        TextCellValue(tx.description),
        DoubleCellValue(tx.signedAmount.toDouble()),
        DoubleCellValue(runningBalance.toDouble()),
      ]);
    }

    return excel;
  }
}