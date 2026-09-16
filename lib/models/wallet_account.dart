import 'package:flutter/material.dart';

/// A wallet "account" — lets the user separate money into
/// categories like Personal, Business, Savings, etc.
class WalletAccount {
  final String id;
  String name;
  IconData icon;
  Color color;
  final DateTime createdAt;

  WalletAccount({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconName': _iconName(icon),
        'color': color.toARGB32(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Account',
      icon: _iconFromName(json['iconName']?.toString()),
      color: Color(
        (json['color'] as num?)?.toInt() ??
            Colors.purple.toARGB32(),
      ),
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  WalletAccount copyWith({
    String? name,
    IconData? icon,
    Color? color,
  }) {
    return WalletAccount(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt,
    );
  }

  // ============================================================
  // ICON SERIALIZATION
  // ============================================================

  static const Map<String, IconData> _iconMap = {
    'person': Icons.person_rounded,
    'work': Icons.work_rounded,
    'savings': Icons.savings_rounded,
    'business': Icons.business_rounded,
    'school': Icons.school_rounded,
    'family': Icons.family_restroom_rounded,
    'card': Icons.credit_card_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
  };

  static String _iconName(IconData icon) {
    for (final entry in _iconMap.entries) {
      if (entry.value == icon) return entry.key;
    }
    return 'wallet';
  }

  static IconData _iconFromName(String? name) {
    return _iconMap[name] ?? Icons.account_balance_wallet_rounded;
  }

  /// Icons the user can choose from when creating an account.
  static List<IconData> get availableIcons =>
      _iconMap.values.toList();

  static List<String> get iconNames => _iconMap.keys.toList();
}