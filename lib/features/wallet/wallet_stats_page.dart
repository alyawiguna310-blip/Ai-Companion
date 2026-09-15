import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/services/wallet_storage_service.dart';
import '../../models/wallet_transaction.dart';

class WalletStatsPage extends StatefulWidget {
  const WalletStatsPage({super.key});

  @override
  State<WalletStatsPage> createState() => _WalletStatsPageState();
}

class _WalletStatsPageState extends State<WalletStatsPage> {
  List<WalletTransaction> _transactions = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final loaded = await WalletStorageService.loadTransactions();
    if (!mounted) return;
    setState(() {
      _transactions = loaded;
      _isLoading = false;
    });
  }

  // --- Weekly Pie Chart Data ---
  Map<String, double> _getWeeklyExpenseByCategory() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final weeklyTransactions = _transactions.where(
      (tx) => tx.isExpense && tx.dateTime.isAfter(sevenDaysAgo),
    );

    final Map<String, double> categoryTotals = {};
    for (var tx in weeklyTransactions) {
      categoryTotals.update(
        tx.category,
        (value) => value + tx.amount.toDouble(),
        ifAbsent: () => tx.amount.toDouble(),
      );
    }
    return categoryTotals;
  }

  // --- Calendar Markers & Totals ---
  Map<DateTime, double> _getDailyNetFlow() {
    final Map<DateTime, double> dailyNet = {};
    for (var tx in _transactions) {
      final day = DateTime.utc(
        tx.dateTime.year,
        tx.dateTime.month,
        tx.dateTime.day,
      );
      dailyNet.update(
        day,
        (value) => value + tx.signedAmount,
        ifAbsent: () => tx.signedAmount.toDouble(),
      );
    }
    return dailyNet;
  }

  List<WalletTransaction> _getSelectedDayTransactions() {
    if (_selectedDay == null) return [];
    return _transactions
        .where(
          (tx) =>
              tx.dateTime.year == _selectedDay!.year &&
              tx.dateTime.month == _selectedDay!.month &&
              tx.dateTime.day == _selectedDay!.day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wallet Statistics")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPieChartSection(),
                const SizedBox(height: 24),
                _buildCalendarSection(),
                const SizedBox(height: 24),
                if (_selectedDay != null)
                  _buildSelectedDayTransactions(),
              ],
            ),
    );
  }

  Widget _buildPieChartSection() {
    final data = _getWeeklyExpenseByCategory();
    if (data.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text("No expenses in the last 7 days."),
          ),
        ),
      );
    }

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    final sections = data.entries.map((entry) {
      final index = data.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value,
        title:
            '${(entry.value / data.values.reduce((a, b) => a + b) * 100).toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Weekly Expense Breakdown",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: data.entries.map((entry) {
                final index = data.keys.toList().indexOf(entry.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: colors[index % colors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(entry.key),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    final dailyNet = _getDailyNetFlow();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Profit & Loss Calendar",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) =>
                  isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final net = dailyNet[
                      DateTime.utc(day.year, day.month, day.day)];
                  if (net != null && net != 0) {
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: net > 0
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3),
                      ),
                      child: Center(child: Text('${day.day}')),
                    );
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayTransactions() {
    final transactions = _getSelectedDayTransactions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Transactions on ${DateFormat('dd MMM yyyy').format(_selectedDay!)}",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          const Text("No transactions on this day.")
        else
          ...transactions.map(
            (tx) => ListTile(
              leading: Icon(
                tx.isIncome
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: tx.isIncome ? Colors.green : Colors.red,
              ),
              title: Text(tx.category),
              subtitle: Text(tx.description),
              trailing: Text(
                '${tx.isIncome ? '+' : '-'}${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(tx.amount)}',
                style: TextStyle(
                  color: tx.isIncome ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}