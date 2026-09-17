import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/wallet_transaction.dart';

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  State<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  TransactionType _type = TransactionType.expense;

  final TextEditingController _amountController =
      TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();

  late String _category =
      WalletCategories.forType(_type).first;

  DateTime _dateTime = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _changeType(TransactionType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      final list = WalletCategories.forType(type);
      if (!list.contains(_category)) {
        _category = list.first;
      }
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );

    if (time == null || !mounted) return;

    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    final raw = _amountController.text.trim();
    final amount = int.tryParse(raw) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Masukkan jumlah yang valid (lebih dari 0).',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    final tx = WalletTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: amount,
      category: _category,
      description: _descriptionController.text.trim(),
      dateTime: _dateTime,
    );

    Navigator.pop(context, tx);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final isExpense = _type == TransactionType.expense;
    final accentColor =
        isExpense ? colorScheme.error : const Color(0xFF00B894);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ------------------------------------------------
            // HEADER
            // ------------------------------------------------
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.22),
                        accentColor.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    isExpense
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Transaction',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isExpense
                            ? 'Record a new expense'
                            : 'Record a new income',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------
            // TYPE TOGGLE
            // ------------------------------------------------
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Expense',
                      icon: Icons.arrow_upward_rounded,
                      selected: isExpense,
                      accentColor: colorScheme.error,
                      onTap: () =>
                          _changeType(TransactionType.expense),
                    ),
                  ),
                  Expanded(
                    child: _TypeButton(
                      label: 'Income',
                      icon: Icons.arrow_downward_rounded,
                      selected: !isExpense,
                      accentColor: const Color(0xFF00B894),
                      onTap: () =>
                          _changeType(TransactionType.income),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ------------------------------------------------
            // AMOUNT
            // ------------------------------------------------
            Text(
              'Amount',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    'Rp',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ------------------------------------------------
            // CATEGORY — PREMIUM GRID
            // ------------------------------------------------
            Text(
              'Category',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _CategoryGrid(
              categories:
                  WalletCategories.forType(_type),
              selected: _category,
              accentColor: accentColor,
              isExpense: isExpense,
              onSelect: (cat) {
                setState(() => _category = cat);
              },
            ),

            const SizedBox(height: 22),

            // ------------------------------------------------
            // DESCRIPTION
            // ------------------------------------------------
            Text(
              'Note (optional)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 2,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. Lunch with friends',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),

            const SizedBox(height: 16),

            // ------------------------------------------------
            // DATE & TIME
            // ------------------------------------------------
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1C1E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colorScheme.primary
                              .withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.event_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date & Time',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'EEEE, dd MMM yyyy • HH:mm',
                              ).format(_dateTime),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color:
                            colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ------------------------------------------------
            // SAVE BUTTON
            // ------------------------------------------------
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  isExpense
                      ? 'Save Expense'
                      : 'Save Income',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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

// ============================================================
// TYPE BUTTON
// ============================================================

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accentColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CATEGORY GRID — the main fix
// ============================================================

class _CategoryGrid extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final Color accentColor;
  final bool isExpense;
  final ValueChanged<String> onSelect;

  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.accentColor,
    required this.isExpense,
    required this.onSelect,
  });

  static const Map<String, IconData> _iconMap = {
    // Income
    'Allowance': Icons.card_giftcard_rounded,
    'Salary': Icons.work_rounded,
    'Gift': Icons.redeem_rounded,
    'Bonus': Icons.star_rounded,
    'Refund': Icons.replay_rounded,
    'Other Income': Icons.add_circle_outline_rounded,
    // Expense
    'Food': Icons.restaurant_rounded,
    'Transport': Icons.directions_bus_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Bills': Icons.receipt_long_rounded,
    'Entertainment': Icons.movie_rounded,
    'Health': Icons.medical_services_rounded,
    'Education': Icons.school_rounded,
    'Other Expense': Icons.more_horiz_rounded,
  };

  IconData _iconFor(String name) =>
      _iconMap[name] ?? Icons.category_rounded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.05,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = cat == selected;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(cat),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.14)
                    : (isDark
                        ? const Color(0xFF1C1C1E)
                        : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.6)
                      : colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                  width: isSelected ? 1.6 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accentColor
                              .withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconFor(cat),
                    size: 22,
                    color: isSelected
                        ? accentColor
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      cat,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? accentColor
                            : colorScheme.onSurface,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}