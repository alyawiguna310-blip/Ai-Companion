import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/notification_service.dart';
import '../../models/reminder.dart';

enum AIPersonality {
  friendly,
  funny,
  serious,
  ayvan,
}

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final List<Reminder> reminders = [];

  final titleController = TextEditingController();
  final messageController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  bool notificationEnabled = true;
  bool _isLoading = true;

  AIPersonality personality = AIPersonality.friendly;

  static const String _storageKey = 'ai_companion_reminders';

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          final loaded = decoded
              .whereType<Map>()
              .map(
                (item) => Reminder.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();

          if (mounted) {
            setState(() {
              reminders
                ..clear()
                ..addAll(loaded);
            });
          }
        }
      }
    } catch (error) {
      debugPrint('Failed to load reminders: $error');
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = reminders.map((item) => item.toJson()).toList();

      await prefs.setString(
        _storageKey,
        jsonEncode(data),
      );
    } catch (error) {
      debugPrint('Failed to save reminders: $error');
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String defaultMessage() {
    switch (personality) {
      case AIPersonality.friendly:
        return "Hai 👋 Jangan lupa ya.";
      case AIPersonality.funny:
        return "WOI 🗿 Jangan lupa dulu 😭";
      case AIPersonality.serious:
        return "Reminder telah dijadwalkan.";
      case AIPersonality.ayvan:
        return "Bro 😭 AI Companion masih Beta, tapi reminder kamu udah siap.";
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> showAddReminderDialog() async {
    titleController.clear();
    messageController.text = defaultMessage();

    selectedDate = DateTime.now();
    selectedTime = TimeOfDay.now();
    personality = AIPersonality.friendly;
    notificationEnabled = true;

    await _showReminderDialog(
      isEdit: false,
      onSave: (reminder) async {
        setState(() {
          reminders.add(reminder);
        });
        await _saveReminders();
      },
    );
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> showEditReminderDialog(int index) async {
    if (index < 0 || index >= reminders.length) return;

    final existing = reminders[index];

    titleController.text = existing.title;
    messageController.text = existing.description;
    selectedDate = existing.dateTime;
    selectedTime = TimeOfDay(
      hour: existing.dateTime.hour,
      minute: existing.dateTime.minute,
    );
    notificationEnabled = existing.notificationId != null;
    personality = AIPersonality.friendly;

    await _showReminderDialog(
      isEdit: true,
      existingId: existing.id,
      existingNotificationId: existing.notificationId,
      onSave: (updated) async {
        if (existing.notificationId != null) {
          try {
            await NotificationService.instance
                .cancelNotification(existing.notificationId!);
          } catch (error) {
            debugPrint('Failed to cancel old notification: $error');
          }
        }

        setState(() {
          reminders[index] = updated;
        });

        await _saveReminders();
      },
    );
  }

  // ============================================================
  // SHARED DIALOG
  // ============================================================

  Future<void> _showReminderDialog({
    required bool isEdit,
    String? existingId,
    int? existingNotificationId,
    required Future<void> Function(Reminder reminder) onSave,
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEdit
                        ? Icons.edit_notifications
                        : Icons.notifications_active,
                  ),
                  const SizedBox(width: 8),
                  Text(isEdit ? "Edit Reminder" : "Reminder BETA"),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: "Reminder Title",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: messageController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "AI Message",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      ListTile(
                        leading: const Icon(Icons.calendar_month),
                        title: const Text("Date"),
                        subtitle: Text(
                          DateFormat("dd MMM yyyy").format(selectedDate),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text("Time"),
                        subtitle: Text(selectedTime.format(context)),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedTime = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<AIPersonality>(
                        initialValue: personality,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "AI Personality",
                        ),
                        items: AIPersonality.values.map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(item.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            personality = value;
                            if (messageController.text.trim().isEmpty) {
                              messageController.text = defaultMessage();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: notificationEnabled,
                        title: const Text("Enable Notification"),
                        subtitle: const Text(
                          "Send notification on selected time",
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            notificationEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;

                    final schedule = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    int? notificationId;

                    if (notificationEnabled) {
                      notificationId =
                          DateTime.now().millisecondsSinceEpoch ~/ 1000;

                      try {
                        await NotificationService.instance
                            .scheduleNotification(
                          id: notificationId,
                          title: "🤖 AI Companion",
                          body: messageController.text.trim().isEmpty
                              ? titleController.text.trim()
                              : messageController.text.trim(),
                          scheduledDate: schedule,
                        );
                      } catch (error) {
                        debugPrint(
                          'Failed to schedule notification: $error',
                        );
                      }
                    }

                    final reminder = Reminder(
                      id: existingId ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      description: messageController.text.trim(),
                      dateTime: schedule,
                      notificationId: notificationId,
                    );

                    await onSave(reminder);

                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: Text(isEdit ? "Update" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteReminder(int index) async {
    if (index < 0 || index >= reminders.length) return;

    final reminder = reminders[index];

    if (reminder.notificationId != null) {
      try {
        await NotificationService.instance
            .cancelNotification(reminder.notificationId!);
      } catch (error) {
        debugPrint('Failed to cancel notification: $error');
      }
    }

    setState(() {
      reminders.removeAt(index);
    });

    await _saveReminders();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reminder"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              backgroundColor: Colors.orange.shade100,
              avatar: const Icon(
                Icons.science,
                size: 18,
                color: Colors.orange,
              ),
              label: const Text("BETA"),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddReminderDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Reminder"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : reminders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Belum ada reminder",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Tekan tombol + untuk membuat reminder baru.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(18),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(
                            Icons.smart_toy,
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(
                          reminder.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reminder.description),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat("dd MMM yyyy")
                                        .format(reminder.dateTime),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat("HH:mm")
                                        .format(reminder.dateTime),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: "edit",
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 10),
                                  Text("Edit"),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: "delete",
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 10),
                                  Text("Delete"),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == "delete") {
                              _deleteReminder(index);
                            }
                            if (value == "edit") {
                              showEditReminderDialog(index);
                            }
                          },
                        ),
                      ),
                    )
                        .animate(delay: (30 * index).ms)
                        .fadeIn(duration: 250.ms)
                        .slideY(
                          begin: 0.06,
                          end: 0,
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            "🤖 Reminder Beta v2.0 • Made by Ayvan",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}