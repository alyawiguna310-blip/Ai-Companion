import 'package:flutter/material.dart';

class SavingGoal {
  final String id;
  final String name;
  final int targetAmount;
  final int currentAmount;
  final DateTime createdAt;
  final DateTime? deadline;
  final Color color;
  final IconData icon;

  const SavingGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.createdAt,
    this.deadline,
    required this.color,
    required this.icon,
  });

  double get progress => targetAmount <= 0
      ? 0
      : (currentAmount / targetAmount).clamp(0.0, 1.0);

  bool get isComplete => currentAmount >= targetAmount;

  SavingGoal copyWith({
    String? name,
    int? targetAmount,
    int? currentAmount,
    DateTime? deadline,
    Color? color,
    IconData? icon,
  }) {
    return SavingGoal(
      id: id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      createdAt: createdAt,
      deadline: deadline ?? this.deadline,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'createdAt': createdAt.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
        'color': color.toARGB32(),
        'iconName': _iconName(icon),
      };

  factory SavingGoal.fromJson(Map<String, dynamic> json) {
    return SavingGoal(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Goal',
      targetAmount: (json['targetAmount'] as num?)?.toInt() ?? 0,
      currentAmount: (json['currentAmount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      deadline: DateTime.tryParse(
        json['deadline']?.toString() ?? '',
      ),
      color: Color(
        (json['color'] as num?)?.toInt() ??
            Colors.orange.toARGB32(),
      ),
      icon: _iconFromName(json['iconName']?.toString()),
    );
  }

  static const Map<String, IconData> _iconMap = {
    'flight': Icons.flight_takeoff_rounded,
    'phone': Icons.phone_android_rounded,
    'laptop': Icons.laptop_mac_rounded,
    'car': Icons.directions_car_rounded,
    'home': Icons.home_rounded,
    'school': Icons.school_rounded,
    'gift': Icons.card_giftcard_rounded,
    'star': Icons.star_rounded,
  };

  static String _iconName(IconData icon) {
    for (final e in _iconMap.entries) {
      if (e.value == icon) return e.key;
    }
    return 'star';
  }

  static IconData _iconFromName(String? name) {
    return _iconMap[name] ?? Icons.star_rounded;
  }

  static List<IconData> get availableIcons =>
      _iconMap.values.toList();
}