import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/saving_goal_storage_service.dart';
import '../../models/saving_goal.dart';

class SavingGoalsPage extends StatefulWidget {
  const SavingGoalsPage({super.key});

  @override
  State<SavingGoalsPage> createState() => _SavingGoalsPageState();
}

class _SavingGoalsPageState extends State<SavingGoalsPage> {
  List<SavingGoal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await SavingGoalStorageService.load();
    if (!mounted) return;
    setState(() {
      _goals = list;
      _isLoading = false;
    });
  }

  Future<void> _addGoal() async {
    final created = await showModalBottomSheet<SavingGoal>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _GoalSheet(),
    );
    if (created == null || !mounted) return;
    final updated = await SavingGoalStorageService.add(created);
    if (!mounted) return;
    setState(() => _goals = updated);
  }

  Future<void> _editGoal(SavingGoal goal) async {
    final edited = await showModalBottomSheet<SavingGoal>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalSheet(existing: goal),
    );
    if (edited == null || !mounted) return;
    final updated = await SavingGoalStorageService.update(edited);
    if (!mounted) return;
    setState(() => _goals = updated);
  }

  Future<void> _addMoney(SavingGoal goal) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          'Add money to ${goal.name}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount (Rp)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(dialogContext, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (amount == null || amount <= 0 || !mounted) return;

    final updated = await SavingGoalStorageService.update(
      goal.copyWith(currentAmount: goal.currentAmount + amount),
    );
    if (!mounted) return;
    setState(() => _goals = updated);
  }

  Future<void> _deleteGoal(SavingGoal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete ${goal.name}?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final updated = await SavingGoalStorageService.remove(goal.id);
    if (!mounted) return;
    setState(() => _goals = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saving Goals',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGoal,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Goal',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? _emptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _goals.length,
                  itemBuilder: (context, i) {
                    final goal = _goals[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GoalCard(
                        goal: goal,
                        onAdd: () => _addMoney(goal),
                        onEdit: () => _editGoal(goal),
                        onDelete: () => _deleteGoal(goal),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.savings_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No saving goals yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a goal and track your progress.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: goal.color.withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: goal.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      goal.icon,
                      color: goal.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_fmt(goal.currentAmount)} / ${_fmt(goal.targetAmount)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (goal.isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'DONE',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor:
                      goal.color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(goal.color),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${(goal.progress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: goal.color,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(
                      'Add money',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(int amount) {
    final digits = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return 'Rp $buf';
  }
}

class _GoalSheet extends StatefulWidget {
  final SavingGoal? existing;
  const _GoalSheet({this.existing});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late TextEditingController _nameController;
  late TextEditingController _targetController;
  late IconData _icon;
  late Color _color;
  DateTime? _deadline;

  final List<Color> _palette = const [
    Color(0xFF6C5CE7),
    Color(0xFF0984E3),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFFD63031),
    Color(0xFFFDCB6E),
    Color(0xFF8E44AD),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _targetController = TextEditingController(
      text: e?.targetAmount.toString() ?? '',
    );
    _icon = e?.icon ?? SavingGoal.availableIcons.first;
    _color = e?.color ?? _palette.first;
    _deadline = e?.deadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    final target = int.tryParse(_targetController.text.trim()) ?? 0;
    if (name.isEmpty || target <= 0) return;

    final result = widget.existing?.copyWith(
          name: name,
          targetAmount: target,
          icon: _icon,
          color: _color,
          deadline: _deadline,
        ) ??
        SavingGoal(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          targetAmount: target,
          createdAt: DateTime.now(),
          deadline: _deadline,
          color: _color,
          icon: _icon,
        );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'New Saving Goal' : 'Edit Goal',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Goal name',
                hintText: 'e.g. New phone, Vacation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target amount (Rp)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: Text(
                _deadline == null
                    ? 'Set a deadline (optional)'
                    : 'Deadline: ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _deadline = null),
                    ),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: SavingGoal.availableIcons
                  .map(
                    (icon) => GestureDetector(
                      onTap: () => setState(() => _icon = icon),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _icon == icon
                              ? _color.withValues(alpha: 0.2)
                              : theme
                                  .colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _icon == icon
                                ? _color
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: _icon == icon
                              ? _color
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: _palette
                  .map(
                    (c) => GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.existing == null ? 'Create' : 'Save',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}