import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ai_companion/models/wallet_transaction.dart';
import 'package:ai_companion/core/services/wallet_storage_service.dart';

/// A structured wallet action extracted from an AI response.
///
/// Only write actions are represented here. Read-only questions
/// (balance, spending, etc.) are answered by the AI using the
/// wallet context we inject — never through an action object.
class WalletAction {
  /// Either 'add_expense' or 'add_income'.
  final String action;

  /// Positive integer in Rupiah.
  final int amount;

  final String category;
  final String description;

  const WalletAction({
    required this.action,
    required this.amount,
    required this.category,
    required this.description,
  });

  bool get isExpense => action == 'add_expense';
  bool get isIncome => action == 'add_income';

  TransactionType get type =>
      isExpense ? TransactionType.expense : TransactionType.income;
}

/// Result of parsing an AI response for wallet actions.
class WalletActionResult {
  /// Extracted action, or null if the response contained none
  /// (or the block failed validation).
  final WalletAction? action;

  /// The AI's text with any wallet action block removed.
  /// Always safe to display in the chat.
  final String cleanText;

  /// Short human-readable reason if a wallet block was found but
  /// could not be parsed or validated.
  final String? parseError;

  const WalletActionResult({
    this.action,
    required this.cleanText,
    this.parseError,
  });

  bool get hasAction => action != null;
}

class WalletActionService {
  WalletActionService._();

  static const String _tagName = 'wallet_action';

  /// Amount threshold (in Rupiah) at or above which a
  /// confirmation dialog is shown before executing an
  /// AI-initiated transaction.
  static const int confirmationThreshold = 100000;

  // ============================================================
  // PARSE
  // ============================================================

  static WalletActionResult parseResponse(String raw) {
    if (raw.trim().isEmpty) {
      return const WalletActionResult(cleanText: '');
    }

    final pattern = RegExp(
      '<$_tagName>\\s*(.*?)\\s*</$_tagName>',
      caseSensitive: false,
      dotAll: true,
    );

    final match = pattern.firstMatch(raw);

    if (match == null) {
      return WalletActionResult(cleanText: raw.trim());
    }

    final jsonPart = match.group(1)?.trim() ?? '';
    final cleanText = raw
        .replaceRange(match.start, match.end, '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    try {
      var jsonText = jsonPart;

      // Strip optional markdown code fences.
      if (jsonText.startsWith('```')) {
        jsonText = jsonText
            .replaceAll(RegExp(r'^```\w*\s*'), '')
            .replaceAll('```', '')
            .trim();
      }

      final decoded = jsonDecode(jsonText);

      if (decoded is! Map) {
        return WalletActionResult(
          cleanText: cleanText,
          parseError: 'Malformed wallet action payload.',
        );
      }

      final action = _validateAction(
        Map<String, dynamic>.from(decoded),
      );

      if (action == null) {
        return WalletActionResult(
          cleanText: cleanText,
          parseError: 'Wallet action failed validation.',
        );
      }

      return WalletActionResult(
        action: action,
        cleanText: cleanText,
      );
    } catch (error) {
      debugPrint('WalletActionService parse error: $error');
      return WalletActionResult(
        cleanText: cleanText,
        parseError: 'Could not read wallet action.',
      );
    }
  }

  // ============================================================
  // VALIDATE
  // ============================================================

  static WalletAction? _validateAction(
    Map<String, dynamic> map,
  ) {
        final rawAction =
        map['action']?.toString().trim().toLowerCase() ?? '';
    if (rawAction != 'add_expense' &&
        rawAction != 'add_income') {
      return null;
    }

    final amountRaw = map['amount'];
    int? amount;

    if (amountRaw is num) {
      amount = amountRaw.toInt();
    } else if (amountRaw is String) {
      amount = int.tryParse(
        amountRaw.replaceAll(RegExp(r'[^0-9]'), ''),
      );
    }

    if (amount == null || amount <= 0) {
      return null;
    }

    final isExpense = rawAction == 'add_expense';

    final category = _normalizeCategory(
      map['category']?.toString(),
      isExpense: isExpense,
    );

    final description =
        map['description']?.toString().trim() ?? '';

    return WalletAction(
      action: rawAction,
      amount: amount,
      category: category,
      description: description,
    );
  }

  /// Maps the AI's category onto a known one when possible,
  /// otherwise returns a trimmed version of whatever it sent.
  static String _normalizeCategory(
    String? raw, {
    required bool isExpense,
  }) {
    final type = isExpense
        ? TransactionType.expense
        : TransactionType.income;

    final list = WalletCategories.forType(type);
    final fallback = WalletCategories.fallbackFor(type);

    if (raw == null || raw.trim().isEmpty) {
      return fallback;
    }

    final needle = raw.trim().toLowerCase();

    for (final candidate in list) {
      if (candidate.toLowerCase() == needle) {
        return candidate;
      }
    }

    for (final candidate in list) {
      if (needle.contains(candidate.toLowerCase()) ||
          candidate.toLowerCase().contains(needle)) {
        return candidate;
      }
    }

    // Unknown category — keep it, but cap the length.
    final cleaned = raw.trim();
    return cleaned.length <= 30
        ? cleaned
        : cleaned.substring(0, 30);
  }

  // ============================================================
  // CONTEXT FOR THE AI
  // ============================================================

  /// Builds the wallet context + action-protocol instructions
  /// that we prepend to every AI request.
  static Future<String> buildContext() async {
    final txs =
        await WalletStorageService.loadTransactions();

    final balance = WalletStorageService.calculateBalance(txs);
    final income = WalletStorageService.totalIncome(txs);
    final expense = WalletStorageService.totalExpense(txs);

    final now = DateTime.now();
    final thisMonth = WalletStorageService.filterByMonth(
      txs,
      now.year,
      now.month,
    );
    final monthIncome =
        WalletStorageService.totalIncome(thisMonth);
    final monthExpense =
        WalletStorageService.totalExpense(thisMonth);

    final buffer = StringBuffer();

    buffer.writeln('=== WALLET CONTEXT ===');
    buffer.writeln(
      'The user has a wallet. The balance is computed from the '
      'transaction list — you never invent numbers.',
    );
    buffer.writeln();
    buffer.writeln('Current balance: ${formatRupiah(balance)}');
    buffer.writeln('Total income: ${formatRupiah(income)}');
    buffer.writeln('Total expense: ${formatRupiah(expense)}');
    buffer.writeln(
      'This month (${now.month}/${now.year}): '
      'income ${formatRupiah(monthIncome)}, '
      'expense ${formatRupiah(monthExpense)}',
    );

    if (txs.isNotEmpty) {
      // Spending by category (all-time).
      final byCategory = <String, int>{};
      for (final tx in txs) {
        if (tx.isExpense) {
          byCategory[tx.category] =
              (byCategory[tx.category] ?? 0) + tx.amount;
        }
      }

      if (byCategory.isNotEmpty) {
        final sorted = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        buffer.writeln();
        buffer.writeln(
          'Total spending by category (all time):',
        );
        for (final entry in sorted) {
          buffer.writeln(
            '- ${entry.key}: ${formatRupiah(entry.value)}',
          );
        }
      }

      // Last 10 transactions.
      final recent = txs.reversed.take(10).toList();
      buffer.writeln();
      buffer.writeln(
        'Recent transactions (newest first):',
      );
      for (final tx in recent) {
        final sign = tx.isIncome ? '+' : '-';
        buffer.writeln(
          '- ${_formatDate(tx.dateTime)} | '
          '${tx.category} | '
          '${tx.description.isEmpty ? "(no description)" : tx.description} | '
          '$sign${formatRupiah(tx.amount)}',
        );
      }
    } else {
      buffer.writeln();
      buffer.writeln('No transactions recorded yet.');
    }

    buffer.writeln();
    buffer.writeln('=== WALLET ACTION PROTOCOL ===');
    buffer.writeln(
      'When the user clearly states an income or an expense, '
      'emit a structured action in EXACTLY this format:',
    );
    buffer.writeln();
    buffer.writeln('<wallet_action>');
    buffer.writeln('{');
    buffer.writeln('  "action": "add_expense",');
    buffer.writeln('  "amount": 25000,');
    buffer.writeln('  "category": "Food",');
    buffer.writeln('  "description": "Lunch"');
    buffer.writeln('}');
    buffer.writeln('</wallet_action>');
    buffer.writeln();
    buffer.writeln('Or for income:');
    buffer.writeln();
    buffer.writeln('<wallet_action>');
    buffer.writeln('{');
    buffer.writeln('  "action": "add_income",');
    buffer.writeln('  "amount": 500000,');
    buffer.writeln('  "category": "Allowance",');
    buffer.writeln('  "description": "Weekly allowance"');
    buffer.writeln('}');
    buffer.writeln('</wallet_action>');
    buffer.writeln();
    buffer.writeln('Rules:');
    buffer.writeln(
      '1. Emit an action ONLY when the user clearly wants a '
      'transaction recorded.',
    );
    buffer.writeln(
      '2. Never guess the amount. If it is missing or unclear, '
      'ask in normal text instead.',
    );
    buffer.writeln(
      '3. Use only the categories: '
      '${WalletCategories.expense.join(", ")} (expense) / '
      '${WalletCategories.income.join(", ")} (income).',
    );
    buffer.writeln(
      '4. Amount is a positive integer in Rupiah. No decimals, '
      'no currency symbols.',
    );
    buffer.writeln(
      '5. Emit only ONE action per response. If the user '
      'mentions several transactions, ask them to handle them '
      'one at a time.',
    );
    buffer.writeln(
      '6. You may add short natural text before or after the '
      'action block, but never inside it.',
    );
    buffer.writeln(
      '7. For questions about the wallet (balance, spending, '
      'etc.), answer directly using the context above — do NOT '
      'emit an action for read-only questions.',
    );
    buffer.writeln(
      '8. Do NOT mention the wallet or its contents unless the '
      'user asks about it or is making a transaction.',
    );
    buffer.writeln('=== END WALLET CONTEXT ===');

    return buffer.toString().trim();
  }

  // ============================================================
  // EXECUTE
  // ============================================================

  /// Executes a validated action by creating the corresponding
  /// transaction and persisting it via [WalletStorageService].
  static Future<WalletTransaction> execute(
    WalletAction action,
  ) async {
    final tx = WalletTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: action.type,
      amount: action.amount,
      category: action.category,
      description: action.description,
      dateTime: DateTime.now(),
    );

    await WalletStorageService.addTransaction(tx);
    return tx;
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  static String formatRupiah(int amount) {
    final isNegative = amount < 0;
    final digits = amount.abs().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return '${isNegative ? '-' : ''}Rp $buffer';
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}