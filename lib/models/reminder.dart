class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final bool completed;
  final int? notificationId;

  const Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    this.completed = false,
    this.notificationId,
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    bool? completed,
    int? notificationId,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      completed: completed ?? this.completed,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'completed': completed,
      'notificationId': notificationId,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      dateTime: DateTime.tryParse(
            json['dateTime']?.toString() ?? '',
          ) ??
          DateTime.now(),
      completed: json['completed'] == true,
      notificationId: (json['notificationId'] as num?)?.toInt(),
    );
  }
}