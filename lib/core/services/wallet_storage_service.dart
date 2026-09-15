import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_companion/models/wallet_transaction.dart';

/// Persists wallet transactions and exposes safe, computed
/// queries on top of them.
///
/// Rules:
/// - The service is the ONLY thing that writes wallet data.
/// - Balance is ALWAYS computed from the transaction list.
/// - No method silently swallows invalid input; callers must
///   pass already-validated data (see WalletActionService in
///   later phases).
class WalletStorageService {
  WalletStorageService._();

  static const String _storageKey =
      'ai_companion_wallet_transactions';

  // ============================================================
  // LOAD
  // ============================================================

  /// Returns all stored transactions.
  ///
  /// Never returns null — returns an empty list on first launch
  /// or if the stored data is unreadable.
  static Future<List<WalletTransaction>>
      loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return <WalletTransaction>[];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return <WalletTransaction>[];
      }

      final transactions = decoded
          .whereType<Map>()
          .map(
            (item) => WalletTransaction.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((tx) => tx.id.isNotEmpty)
          .toList();

      _sortInPlace(transactions);
      return transactions;
    } catch (_) {
      return <WalletTransaction>[];
    }
  }

  // ============================================================
  // SAVE (full replace)
  // ============================================================

  static Future<void> saveTransactions(
    List<WalletTransaction> transactions,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final data = transactions
        .map((tx) => tx.toJson())
        .toList();

    await prefs.setString(_storageKey, jsonEncode(data));
  }

  // ============================================================
  // ADD
  // ============================================================

  /// Adds [transaction] and persists the updated list.
  ///
  /// Duplicate IDs are ignored to protect against double-adds.
  static Future<List<WalletTransaction>> addTransaction(
    WalletTransaction transaction,
  ) async {
    final current = await loadTransactions();

    final alreadyExists = current.any(
      (tx) => tx.id == transaction.id,
    );

    if (alreadyExists) {
      return current;
    }

    current.add(transaction);
    _sortInPlace(current);

    await saveTransactions(current);
    return current;
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<List<WalletTransaction>> deleteTransaction(
    String id,
  ) async {
    if (id.isEmpty) {
      return loadTransactions();
    }

    final current = await loadTransactions();

    current.removeWhere((tx) => tx.id == id);

    await saveTransactions(current);
    return current;
  }

  // ============================================================
  // CLEAR
  // ============================================================

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ============================================================
  // BALANCE (computed, never stored)
  // ============================================================

  static int calculateBalance(
    List<WalletTransaction> transactions,
  ) {
    var total = 0;
    for (final tx in transactions) {
      total += tx.signedAmount;
    }
    return total;
  }

  // ============================================================
  // SUMMARY HELPERS
  // ============================================================

  static int totalIncome(
    List<WalletTransaction> transactions,
  ) {
    var total = 0;
    for (final tx in transactions) {
      if (tx.isIncome) total += tx.amount;
    }
    return total;
  }

  static int totalExpense(
    List<WalletTransaction> transactions,
  ) {
    var total = 0;
    for (final tx in transactions) {
      if (tx.isExpense) total += tx.amount;
    }
    return total;
  }

  /// Case-insensitive match on the transaction category.
  static List<WalletTransaction> filterByCategory(
    List<WalletTransaction> transactions,
    String category,
  ) {
    final needle = category.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    return transactions
        .where(
          (tx) =>
              tx.category.trim().toLowerCase() == needle,
        )
        .toList();
  }

  /// Returns transactions whose [WalletTransaction.dateTime] falls
  /// inside [year]/[month]. Month is 1-based (1 = January).
  static List<WalletTransaction> filterByMonth(
    List<WalletTransaction> transactions,
    int year,
    int month,
  ) {
    return transactions
        .where(
          (tx) =>
              tx.dateTime.year == year &&
              tx.dateTime.month == month,
        )
        .toList();
  }

  // ============================================================
  // ORDERING
  // ============================================================

  /// Oldest first, newest last — matches the Excel export order
  /// where each row shows a running balance.
  ///
  /// Ties on [dateTime] fall back to [createdAt] so ordering is
  /// always stable.
  static void _sortInPlace(
    List<WalletTransaction> transactions,
  ) {
    transactions.sort((a, b) {
      final byDate = a.dateTime.compareTo(b.dateTime);
      if (byDate != 0) return byDate;
      return a.createdAt.compareTo(b.createdAt);
    });
  }
}