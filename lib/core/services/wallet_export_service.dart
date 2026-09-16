import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ai_companion/models/wallet_transaction.dart';
import 'package:ai_companion/core/services/wallet_storage_service.dart';

class WalletExportService {
  WalletExportService._();

  // ============================================================
  // SHARE SHEET (anywhere: WhatsApp, email, Drive, Files, ...)
  // ============================================================

  static Future<String> exportAndShare({
    String shareSubject = 'Aicompanion Wallet Export',
    String shareText =
        'Wallet transactions exported from Aicompanion.',
  }) async {
    final transactions =
        await WalletStorageService.loadTransactions();

    if (transactions.isEmpty) {
      throw Exception('No transactions to export.');
    }

    final bytes = _buildBytes(transactions);
    final tempDir = await getTemporaryDirectory();
    final fileName = _fileName();

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
      subject: shareSubject,
      text: shareText,
    );

    return file.path;
  }

  // ============================================================
  // SAVE TO DEVICE (Android SAF "Save to" dialog)
  // ============================================================

  /// Opens Android's native save dialog. User can pick
  /// Downloads, Documents, or any folder. Returns the saved
  /// path, or null if the user cancelled.
  static Future<String?> exportAndSaveToDevice() async {
    final transactions =
        await WalletStorageService.loadTransactions();

    if (transactions.isEmpty) {
      throw Exception('No transactions to export.');
    }

    final bytes = _buildBytes(transactions);
    final fileName = _fileName();

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save wallet export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      bytes: Uint8List.fromList(bytes),
    );

    return savedPath;
  }

  // ============================================================
  // INTERNAL
  // ============================================================

  static String _fileName() =>
      'Aicompanion_Wallet_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';

  static List<int> _buildBytes(
    List<WalletTransaction> transactions,
  ) {
    final excel = _buildWorkbook(transactions);
    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file.');
    }
    return bytes;
  }

  static Excel _buildWorkbook(
    List<WalletTransaction> transactions,
  ) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    if (defaultSheet != null) {
      excel.rename(defaultSheet, 'Transactions');
    }

    final sheet = excel['Transactions'];

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 10);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 20);
    sheet.setColumnWidth(4, 34);
    sheet.setColumnWidth(5, 18);
    sheet.setColumnWidth(6, 18);

    sheet.appendRow(<CellValue>[
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Description'),
      TextCellValue('Amount'),
      TextCellValue('Balance'),
    ]);

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