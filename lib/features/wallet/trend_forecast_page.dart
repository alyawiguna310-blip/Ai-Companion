import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/wallet_storage_service.dart';
import '../../models/wallet_transaction.dart';

class TrendForecastPage extends StatefulWidget {
  const TrendForecastPage({super.key});

  @override
  State<TrendForecastPage> createState() => _TrendForecastPageState();
}

class _TrendForecastPageState extends State<TrendForecastPage> {
  List<WalletTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final txs = await WalletStorageService.loadTransactions();
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _isLoading = false;
    });
  }

  /// Returns the last N months (oldest first) with total income
  /// and expense per month.
  List<_MonthStat> _monthlyStats({int months = 6}) {
    final now = DateTime.now();
    final result = <_MonthStat>[];

    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      var income = 0;
      var expense = 0;

      for (final tx in _transactions) {
        if (tx.dateTime.year != m.year ||
            tx.dateTime.month != m.month) {
          continue;
        }
        if (tx.isIncome) {
          income += tx.amount;
        } else {
          expense += tx.amount;
        }
      }

      result.add(
        _MonthStat(month: m, income: income, expense: expense),
      );
    }
    return result;
  }

  /// Simple linear-regression style forecast based on the
  /// average month-over-month change.
  String _forecastText(List<_MonthStat> stats) {
    if (stats.length < 2) return 'Not enough data yet.';

    final expenses =
        stats.map((s) => s.expense).toList();
    var sumDelta = 0;
    for (var i = 1; i < expenses.length; i++) {
      sumDelta += expenses[i] - expenses[i - 1];
    }
    final avgDelta = sumDelta / (expenses.length - 1);

    final lastExpense = expenses.last;
    final projected = (lastExpense + avgDelta).clamp(0, 1 << 30);

    final direction = avgDelta > 0
        ? 'likely to increase'
        : avgDelta < 0
            ? 'likely to decrease'
            : 'likely to stay about the same';

    return 'Next month, your spending is $direction. '
        'Estimated at ${_fmt(projected.toInt())}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _monthlyStats();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trend Forecast',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary
                            .withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forecast',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _forecastText(stats),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Last 6 months',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: SizedBox(
                    height: 240,
                    child: _buildChart(stats, theme),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Legend(color: Colors.green, label: 'Income'),
                    const SizedBox(width: 16),
                    _Legend(
                      color: theme.colorScheme.error,
                      label: 'Expense',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Monthly breakdown',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...stats.reversed.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(
                            DateFormat('MMM yy').format(s.month),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'In ${_fmt(s.income)}  •  Out ${_fmt(s.expense)}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: theme.colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChart(List<_MonthStat> stats, ThemeData theme) {
    if (stats.every((s) => s.income == 0 && s.expense == 0)) {
      return Center(
        child: Text(
          'No data to chart yet.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxY = stats
            .expand((s) => [s.income, s.expense])
            .fold<int>(0, (a, b) => a > b ? a : b)
            .toDouble() *
        1.15;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (stats.length - 1).toDouble(),
        minY: 0,
        maxY: maxY == 0 ? 100 : maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (v) => FlLine(
            color: theme.colorScheme.outlineVariant
                .withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return Text(
                  _short(value.toInt()),
                  style: GoogleFonts.poppins(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= stats.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MMM').format(stats[i].month),
                    style: GoogleFonts.poppins(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _line(
            color: Colors.green,
            values: stats.map((s) => s.income.toDouble()).toList(),
          ),
          _line(
            color: theme.colorScheme.error,
            values: stats.map((s) => s.expense.toDouble()).toList(),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line({
    required Color color,
    required List<double> values,
  }) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++)
          FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      curveSmoothness: 0.28,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, _, _) {
          return FlDotCirclePainter(
            radius: 4,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.12),
      ),
    );
  }

  static String _fmt(int amount) {
    final digits = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return 'Rp $buf';
  }

  static String _short(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return '$amount';
  }
}

class _MonthStat {
  final DateTime month;
  final int income;
  final int expense;

  _MonthStat({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      ],
    );
  }
}