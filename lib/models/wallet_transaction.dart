/// Direction of a wallet transaction.
///
/// [income]  → money coming in  (+)
/// [expense] → money going out  (-)
enum TransactionType {
  income,
  expense,
}

/// A single wallet transaction.
///
/// Amount is always stored as a **positive integer** in Rupiah.
/// The sign is derived from [type] at read/display time.
/// Balance is never persisted — it is always computed by
/// summing transactions in [WalletStorageService].
class WalletTransaction {
  /// Stable, unique identifier for this transaction.
  final String id;

  /// Income or expense.
  final TransactionType type;

  /// Always positive. Rupiah (no decimals).
  final int amount;

  /// Free-form but usually one of the suggested categories in
  /// [WalletCategories]. Kept as a plain String so a transaction
  /// can still be saved even if its category isn't in the list.
  final String category;

  /// Human description (may be empty).
  final String description;

  /// When the transaction happened (user-visible date/time).
  final DateTime dateTime;

  /// When the record was created (used only for stable ordering).
  final DateTime createdAt;

  /// Which wallet account this transaction belongs to.
  /// Defaults to 'personal' for backward compatibility with
  /// transactions saved before accounts existed.
  final String accountId;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.description = '',
    required this.dateTime,
    DateTime? createdAt,
    this.accountId = 'personal',
  }) : createdAt = createdAt ?? DateTime.now();

  /// Signed amount for balance math and Excel export.
  ///
  /// Income  → positive
  /// Expense → negative
  int get signedAmount =>
      type == TransactionType.income ? amount : -amount;

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  // ============================================================
  // SERIALIZATION
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category': category,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'accountId': accountId,
    };
  }

  factory WalletTransaction.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawType = json['type']?.toString();
    final type = TransactionType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => TransactionType.expense,
    );

    // Amount must always be non-negative on the way in.
    // If a stored value is negative (legacy / corrupted),
    // take its absolute value so signedAmount stays correct.
    final rawAmount = (json['amount'] as num?)?.toInt() ?? 0;
    final safeAmount = rawAmount < 0 ? -rawAmount : rawAmount;

    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: type,
      amount: safeAmount,
      category: json['category']?.toString() ?? 'Other',
      description: json['description']?.toString() ?? '',
      dateTime: DateTime.tryParse(
            json['dateTime']?.toString() ?? '',
          ) ??
          DateTime.now(),
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      accountId: json['accountId']?.toString() ?? 'personal',
    );
  }

  WalletTransaction copyWith({
    String? id,
    TransactionType? type,
    int? amount,
    String? category,
    String? description,
    DateTime? dateTime,
    DateTime? createdAt,
    String? accountId,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      createdAt: createdAt ?? this.createdAt,
      accountId: accountId ?? this.accountId,
    );
  }
}

/// Suggested categories for the UI picker and the future AI
/// wallet-action validator. Free-form strings are still allowed —
/// these are only defaults.
class WalletCategories {
  WalletCategories._();

  static const List<String> income = <String>[
    'Allowance',
    'Salary',
    'Gift',
    'Bonus',
    'Refund',
    'Other Income',
  ];

  static const List<String> expense = <String>[
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Other Expense',
  ];

  /// Fallback if the AI or the user supplies something unknown.
  static const String fallbackIncome = 'Other Income';
  static const String fallbackExpense = 'Other Expense';

  static List<String> forType(TransactionType type) {
    return type == TransactionType.income ? income : expense;
  }

  static String fallbackFor(TransactionType type) {
    return type == TransactionType.income
        ? fallbackIncome
        : fallbackExpense;
  }
}