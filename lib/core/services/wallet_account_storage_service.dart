import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_companion/models/wallet_account.dart';

class WalletAccountStorageService {
  WalletAccountStorageService._();

  static const String _storageKey =
      'ai_companion_wallet_accounts';

  /// IDs of the two accounts seeded on first launch.
  static const String defaultPersonalId = 'personal';
  static const String defaultBusinessId = 'business';

  static Future<List<WalletAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      // First launch — seed defaults.
      final defaults = _seedDefaults();
      await save(defaults);
      return defaults;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _seedDefaults();

      final accounts = decoded
          .whereType<Map>()
          .map(
            (item) => WalletAccount.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((a) => a.id.isNotEmpty)
          .toList();

      if (accounts.isEmpty) return _seedDefaults();
      return accounts;
    } catch (_) {
      return _seedDefaults();
    }
  }

  static Future<void> save(List<WalletAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  static Future<List<WalletAccount>> add(
    WalletAccount account,
  ) async {
    final current = await load();
    current.add(account);
    await save(current);
    return current;
  }

  static Future<List<WalletAccount>> update(
    WalletAccount account,
  ) async {
    final current = await load();
    final i = current.indexWhere((a) => a.id == account.id);
    if (i != -1) current[i] = account;
    await save(current);
    return current;
  }

  static Future<List<WalletAccount>> remove(String id) async {
    final current = await load();
    current.removeWhere((a) => a.id == id);
    await save(current);
    return current;
  }

  static List<WalletAccount> _seedDefaults() {
    return [
      WalletAccount(
        id: defaultPersonalId,
        name: 'Personal',
        icon: Icons.person_rounded,
        color: const Color(0xFF6C5CE7),
      ),
      WalletAccount(
        id: defaultBusinessId,
        name: 'Business',
        icon: Icons.work_rounded,
        color: const Color(0xFF0984E3),
      ),
    ];
  }
}