import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/wallet_export_service.dart';
import '../../core/services/wallet_storage_service.dart';
import 'wallet_stats_page.dart';

/// The Wallet "More" hub — a premium, grouped grid of tools.
///
/// Design language:
///   • Large hero header with live balance + net flow
///   • Grouped sections (Insights / Manage / System)
///   • Each tile has its own color identity and soft gradient
///   • Staggered entrance animations
///   • Tactile press feedback (scale + ink)
class WalletMorePage extends StatefulWidget {
  const WalletMorePage({super.key});

  @override
  State<WalletMorePage> createState() => _WalletMorePageState();
}

class _WalletMorePageState extends State<WalletMorePage> {
  int _balance = 0;
  int _income = 0;
  int _expense = 0;
  int _txCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final txs = await WalletStorageService.loadTransactions();
    if (!mounted) return;
    setState(() {
      _balance = WalletStorageService.calculateBalance(txs);
      _income = WalletStorageService.totalIncome(txs);
      _expense = WalletStorageService.totalExpense(txs);
      _txCount = txs.length;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ================================================
            // PREMIUM APP BAR
            // ================================================
            SliverAppBar(
              pinned: false,
              floating: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 20,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary
                              .withValues(alpha: 0.65),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary
                              .withValues(alpha: 0.3),
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
                    'Wallet Tools',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // ================================================
            // HERO BALANCE CARD
            // ================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: _HeroBalanceCard(
                  balance: _balance,
                  income: _income,
                  expense: _expense,
                  txCount: _txCount,
                  isLoading: _isLoading,
                ),
              ),
            ),

            // ================================================
            // SECTION — INSIGHTS
            // ================================================
            const _SectionHeader(
              title: 'Insights',
              subtitle: 'Understand your money',
            ).toSliver(),

            _buildGridSection(
              context,
              tiles: [
                _TileData(
                  icon: Icons.insights_rounded,
                  label: 'Statistics',
                  accent: const Color(0xFF6C5CE7),
                  onTap: () => _open(
                    context,
                    const WalletStatsPage(),
                  ),
                ),
                _TileData(
                  icon: Icons.show_chart_rounded,
                  label: 'Trend Forecast',
                  accent: const Color(0xFF00B894),
                  badge: 'BETA',
                  onTap: () =>
                      _comingSoon(context, 'Trend Forecast'),
                ),
                _TileData(
                  icon: Icons.pie_chart_rounded,
                  label: 'Budget',
                  accent: const Color(0xFFE17055),
                  onTap: () =>
                      _comingSoon(context, 'Budget Management'),
                ),
              ],
              startDelay: 100,
            ),

            // ================================================
            // SECTION — MANAGE
            // ================================================
            const _SectionHeader(
              title: 'Manage',
              subtitle: 'Organize and control',
            ).toSliver(),

            _buildGridSection(
              context,
              tiles: [
                _TileData(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  accent: const Color(0xFF0984E3),
                  onTap: () =>
                      _comingSoon(context, 'Search Transactions'),
                ),
                _TileData(
                  icon: Icons.category_rounded,
                  label: 'Categories',
                  accent: const Color(0xFFD63031),
                  onTap: () => _comingSoon(
                    context,
                    'Category Management',
                  ),
                ),
                _TileData(
                  icon: Icons.repeat_rounded,
                  label: 'Recurring',
                  accent: const Color(0xFF00CEC9),
                  onTap: () =>
                      _comingSoon(context, 'Recurring'),
                ),
                _TileData(
                  icon: Icons.savings_rounded,
                  label: 'Saving Goals',
                  accent: const Color(0xFFFDCB6E),
                  onTap: () =>
                      _comingSoon(context, 'Saving Goals'),
                ),
                _TileData(
                  icon: Icons.file_download_rounded,
                  label: 'Export Excel',
                  accent: const Color(0xFF27AE60),
                  onTap: () => _export(context),
                ),
                _TileData(
                  icon: Icons.backup_rounded,
                  label: 'Backup',
                  accent: const Color(0xFF8E44AD),
                  onTap: () =>
                      _comingSoon(context, 'Backup & Restore'),
                ),
              ],
              startDelay: 300,
            ),

            // ================================================
            // FOOTER
            // ================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI Companion 2.0 • BETA',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GRID SECTION BUILDER
  // ============================================================

  Widget _buildGridSection(
    BuildContext context, {
    required List<_TileData> tiles,
    required int startDelay,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      sliver: SliverGrid(
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _PremiumTile(
              data: tiles[index],
              delay: startDelay + (index * 60),
            );
          },
          childCount: tiles.length,
        ),
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await WalletExportService.exportAndShare();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Excel file ready. Choose where to save it.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Export failed: $error',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  void _comingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name is coming soon.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ============================================================
// HERO BALANCE CARD
// ============================================================

class _HeroBalanceCard extends StatelessWidget {
  final int balance;
  final int income;
  final int expense;
  final int txCount;
  final bool isLoading;

  const _HeroBalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
    required this.txCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            const Color(0xFF8E5CF7),
            colorScheme.primary.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 60,
            offset: const Offset(0, 20),
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
                      'LIVE',
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
          if (isLoading)
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
            )
          else
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
                    value: _formatShort(income),
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
                    value: _formatShort(expense),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Records',
                    value: '$txCount',
                    icon: Icons.receipt_long_rounded,
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

  static String _formatRupiah(int amount) {
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

  static String _formatShort(int amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (amount >= 1000) {
      final k = amount / 1000;
      return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}k';
    }
    return '$amount';
  }
}

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
        Icon(
          icon,
          size: 14,
          color: Colors.white.withValues(alpha: 0.75),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget toSliver() {
    return SliverToBoxAdapter(child: this);
  }
}

// ============================================================
// PREMIUM TILE
// ============================================================

class _TileData {
  final IconData icon;
  final String label;
  final Color accent;
  final String? badge;
  final VoidCallback onTap;

  const _TileData({
    required this.icon,
    required this.label,
    required this.accent,
    this.badge,
    required this.onTap,
  });
}

class _PremiumTile extends StatefulWidget {
  final _TileData data;
  final int delay;

  const _PremiumTile({
    required this.data,
    required this.delay,
  });

  @override
  State<_PremiumTile> createState() => _PremiumTileState();
}

class _PremiumTileState extends State<_PremiumTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final data = widget.data;
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: data.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: data.accent.withValues(alpha: 0.14),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Stack(
              children: [
                // Subtle gradient wash top-right.
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          data.accent.withValues(alpha: 0.15),
                          data.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              data.accent.withValues(alpha: 0.22),
                              data.accent.withValues(alpha: 0.10),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: data.accent
                                .withValues(alpha: 0.20),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          data.icon,
                          size: 24,
                          color: data.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: Text(
                          data.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: -0.1,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.badge != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            data.accent,
                            data.accent.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: data.accent
                                .withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        data.badge!,
                        style: GoogleFonts.poppins(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.delay))
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.15,
          end: 0,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }
}