import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_companion/models/saving_goal.dart';

class SavingGoalStorageService {
  SavingGoalStorageService._();

  static const String _storageKey =
      'ai_companion_saving_goals';

  static Future<List<SavingGoal>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => SavingGoal.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((g) => g.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<SavingGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(goals.map((g) => g.toJson()).toList()),
    );
  }

  static Future<List<SavingGoal>> add(SavingGoal goal) async {
    final current = await load();
    current.add(goal);
    await save(current);
    return current;
  }

  static Future<List<SavingGoal>> update(SavingGoal goal) async {
    final current = await load();
    final i = current.indexWhere((g) => g.id == goal.id);
    if (i != -1) current[i] = goal;
    await save(current);
    return current;
  }

  static Future<List<SavingGoal>> remove(String id) async {
    final current = await load();
    current.removeWhere((g) => g.id == id);
    await save(current);
    return current;
  }
}