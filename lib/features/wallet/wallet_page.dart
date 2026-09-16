import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/wallet_account_storage_service.dart';
import '../../core/services/wallet_export_service.dart';
import '../../core/services/wallet_storage_service.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_transaction.dart';
import 'add_transaction_sheet.dart';
import 'wallet_accounts_page.dart';
import 'wallet_more_page.dart';
import 'wallet_stats_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  List<WalletTransaction> _transactions = [];
  List<WalletAccount> _accounts = [];
  String _activeAccountId =
      WalletAccountStorageService.defaultPersonalId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await WalletAccountStorageService.load();
    final loaded = await WalletStorageService.loadTransactions();

    if (!mounted) return;

    // Make sure active account still exists.
    var activeId = _activeAccountId;
    if (accounts.isNotEmpty &&
        !accounts.any((a) => a.id == activeId)) {
      activeId = accounts.first.id;
    }

    setState(() {
      _accounts = accounts;
      _activeAccountId = activeId;
      _transactions = loaded;
      _isLoading = false;
    });
  }

  // ============================================================
  // GETTERS
  // ============================================================

  List<WalletTransaction> get _visibleTransactions =>
      _transactions
          .where((tx) => tx.accountId == _activeAccountId)
          .toList();

  WalletAccount? get _activeAccount {
    if (_accounts.isEmpty) return null;
    for (final a in _accounts) {
      if (a.id == _activeAccountId) return a;
    }
    return _accounts.first;
  }

  // ============================================================
  // TRANSACTIONS
  // ============================================================

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<WalletTransaction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => const AddTransactionSheet(),
    );

    if (result == null || !mounted) return;

    final stamped = result.copyWith(accountId: _activeAccountId);
    final updated =
        await WalletStorageService.addTransaction(stamped);

    if (!mounted) return;
    setState(() {
      _transactions = updated;
    });
  }

  Future<void> _confirmDelete(WalletTransaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Delete transaction?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '${tx.category}  •  ${_formatRupiah(tx.signedAmount)}\n\n'
            'This action cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final updated =
        await WalletStorageService.deleteTransaction(tx.id);
    if (!mounted) return;
    setState(() {
      _transactions = updated;
    });
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalletStatsPage(),
      ),
    );
  }

  void _openMore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalletMorePage(),
      ),
    );
  }

  Future<void> _openAccounts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WalletAccountsPage(),
      ),
    );
    _load();
  }

  Future<void> _handleExport() async {
    final visible = _visibleTransactions;
    if (visible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions to export yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await WalletExportService.exportAndShare();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Excel file ready. Choose where to save it.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String _formatRupiah(int amount) {
    final isNegative = amount < 0;
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return '${isNegative ? '-' : ''}Rp $buffer';
  }

  IconData _iconFor(WalletTransaction tx) {
    if (tx.isIncome) {
      switch (tx.category) {
        case 'Allowance':
          return Icons.card_giftcard;
        case 'Salary':
          return Icons.work_outline;
        case 'Gift':
          return Icons.redeem;
        case 'Bonus':
          return Icons.star_outline;
        case 'Refund':
          return Icons.replay;
        default:
          return Icons.arrow_downward_rounded;
      }
    }
    switch (tx.category) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_bus_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Bills':
        return Icons.receipt_long_rounded;
      case 'Entertainment':
        return Icons.movie_rounded;
      case 'Health':
        return Icons.medical_services_rounded;
      case 'Education':
        return Icons.school_rounded;
      default:
        return Icons.arrow_upward_rounded;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.65),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:
                        colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Wallet',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Wallet statistics',
            onPressed: _openStats,
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            tooltip: 'More tools',
            onPressed: _openMore,
            icon: const Icon(Icons.grid_view_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Quick actions',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') _handleExport();
            },
            itemBuilder: (menuContext) {
              return const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text('Export to Excel'),
                    ],
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'wallet-add-transaction',
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Transaction',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    100,
                  ),
                  children: [
                    _buildHeroCard(theme),
                    const SizedBox(height: 14),
                    _buildAccountChips(theme),
                    const SizedBox(height: 20),
                    if (_visibleTransactions.isEmpty)
                      _buildEmptyState(theme)
                    else ...[
                      Row(
                        children: [
                          Text(
                            'Recent activity',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_visibleTransactions.length} record'
                            '${_visibleTransactions.length == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color:
                                  colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._buildTransactionList(theme),
                    ],
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'AI Companion 2.0 • BETA',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color:
                              colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================

  Widget _buildHeroCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final visible = _visibleTransactions;
    final balance =
        WalletStorageService.calculateBalance(visible);
    final income = WalletStorageService.totalIncome(visible);
    final expense = WalletStorageService.totalExpense(visible);
    final account = _activeAccount;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            account?.color ?? colorScheme.primary,
            const Color(0xFF8E5CF7),
            (account?.color ?? colorScheme.primary)
                .withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: (account?.color ?? colorScheme.primary)
                .withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (account?.name ?? 'Personal').toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Current Balance',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatRupiah(balance),
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Income',
                    value: _formatRupiah(income),
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Expense',
                    value: _formatRupiah(expense),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(
          begin: 0.08,
          end: 0,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // ACCOUNT CHIPS
  // ============================================================

  Widget _buildAccountChips(ThemeData theme) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _accounts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _accounts.length) {
            return ActionChip(
              avatar: Icon(
                Icons.settings_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(
                'Manage',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              onPressed: _openAccounts,
            );
          }

          final account = _accounts[index];
          final selected = account.id == _activeAccountId;

          return ChoiceChip(
            avatar: Icon(
              account.icon,
              size: 16,
              color: selected ? Colors.white : account.color,
            ),
            label: Text(
              account.name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurface,
              ),
            ),
            selected: selected,
            selectedColor: account.color,
            backgroundColor:
                theme.colorScheme.surfaceContainerHighest,
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _activeAccountId = account.id);
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // TRANSACTION LIST
  // ============================================================

  List<Widget> _buildTransactionList(ThemeData theme) {
    final displayOrder = _visibleTransactions.reversed.toList();

    return displayOrder.asMap().entries.map(
      (entry) {
        final index = entry.key;
        final tx = entry.value;

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TransactionTile(
              transaction: tx,
              icon: _iconFor(tx),
              formattedAmount: _formatRupiah(tx.signedAmount),
              formattedDate:
                  DateFormat('dd MMM yyyy • HH:mm')
                      .format(tx.dateTime),
              onDelete: () => _confirmDelete(tx),
            )
                .animate(
                  key: ValueKey<String>('tx-${tx.id}'),
                  delay: Duration(
                    milliseconds: (30 * index).clamp(0, 300),
                  ),
                )
                .fadeIn(duration: 220.ms)
                .slideY(
                  begin: 0.05,
                  end: 0,
                  duration: 220.ms,
                  curve: Curves.easeOutCubic,
                ),
          ),
        );
      },
    ).toList();
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 44,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No transactions yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap "Add Transaction" to record your '
              'first income or expense.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MINI STAT
// ============================================================

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TRANSACTION TILE
// ============================================================

class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  final IconData icon;
  final String formattedAmount;
  final String formattedDate;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.transaction,
    required this.icon,
    required this.formattedAmount,
    required this.formattedDate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIncome = transaction.isIncome;
    final isDark = theme.brightness == Brightness.dark;

    final accentColor = isIncome
        ? const Color(0xFF00B894)
        : const Color(0xFFE74C3C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.22),
                      accentColor.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.category,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (transaction.description
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        transaction.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedAmount,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
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
}