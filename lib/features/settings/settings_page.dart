import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/theme_service.dart';
import '../../core/services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '—';
  UpdateInfo? _pendingUpdate;
  bool _isChecking = false;
  bool _hasChecked = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    // Auto-check once per page lifetime.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkForUpdates(silent: true);
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _lastError = null;
    });

    final result = await UpdateService.check();

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _hasChecked = true;
      _pendingUpdate = result;
    });

    if (result != null) {
      await _showUpdateDialog(result);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are on the latest version.',
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

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.system_update_alt_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update available',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'v${info.latestVersion}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    info.title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      info.notes.trim().isEmpty
                          ? 'No release notes provided.'
                          : info.notes.trim(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Get it'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      await _openDownload(info);
    }
  }

  Future<void> _openDownload(UpdateInfo info) async {
    final target = info.apkUrl?.isNotEmpty == true
        ? info.apkUrl!
        : info.releaseUrl;

    if (target.isEmpty) {
      _showError('No download URL available.');
      return;
    }

    final uri = Uri.tryParse(target);
    if (uri == null) {
      _showError('Invalid download URL.');
      return;
    }

    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        _showError('Could not open download link.');
      }
    } catch (e) {
      if (mounted) _showError('Failed to open link: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

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
                    color: colorScheme.primary
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Settings',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            // -------------------------------------------------
            // APPEARANCE
            // -------------------------------------------------
            _sectionLabel(context, 'Appearance'),
            const SizedBox(height: 10),
            const _ThemeSelectorCard()
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 28),

            // -------------------------------------------------
            // UPDATES
            // -------------------------------------------------
            _sectionLabel(context, 'Updates'),
            const SizedBox(height: 10),
            _UpdateTile(
              version: _appVersion,
              isChecking: _isChecking,
              hasChecked: _hasChecked,
              pendingUpdate: _pendingUpdate,
              error: _lastError,
              onCheck: () => _checkForUpdates(),
            )
                .animate(delay: 80.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 28),

            // -------------------------------------------------
            // ABOUT
            // -------------------------------------------------
            _sectionLabel(context, 'About'),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.smart_toy_outlined,
              title: 'AI Companion',
              subtitle: 'Version $_appVersion • BETA',
            )
                .animate(delay: 140.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.person_outline_rounded,
              title: 'Made by',
              subtitle: 'Ayvan',
            )
                .animate(delay: 200.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ============================================================
// UPDATE TILE
// ============================================================

class _UpdateTile extends StatelessWidget {
  final String version;
  final bool isChecking;
  final bool hasChecked;
  final UpdateInfo? pendingUpdate;
  final String? error;
  final VoidCallback onCheck;

  const _UpdateTile({
    required this.version,
    required this.isChecking,
    required this.hasChecked,
    required this.pendingUpdate,
    required this.error,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Determine state visuals.
    late Color accent;
    late IconData icon;
    late String subtitle;

    if (pendingUpdate != null) {
      accent = const Color(0xFF00B894);
      icon = Icons.system_update_alt_rounded;
      subtitle = 'v${pendingUpdate!.latestVersion} is available';
    } else if (isChecking) {
      accent = colorScheme.primary;
      icon = Icons.sync_rounded;
      subtitle = 'Checking GitHub...';
    } else if (error != null) {
      accent = colorScheme.error;
      icon = Icons.error_outline_rounded;
      subtitle = error!;
    } else if (hasChecked) {
      accent = const Color(0xFF6C5CE7);
      icon = Icons.check_circle_outline_rounded;
      subtitle = 'You are on the latest version';
    } else {
      accent = colorScheme.primary;
      icon = Icons.cloud_outlined;
      subtitle = 'Tap to check for updates';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isChecking ? null : onCheck,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: isChecking
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            accent,
                          ),
                        ),
                      )
                    : Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'App version',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                            'v$version',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: pendingUpdate != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isChecking)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// THEME SELECTOR (unchanged)
// ============================================================

class _ThemeSelectorCard extends StatelessWidget {
  const _ThemeSelectorCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeService.mode,
        builder: (context, currentMode, _) {
          return Row(
            children: [
              Expanded(
                child: _ModeButton(
                  mode: ThemeMode.system,
                  current: currentMode,
                  icon: Icons.brightness_auto_rounded,
                  label: 'System',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ModeButton(
                  mode: ThemeMode.light,
                  current: currentMode,
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ModeButton(
                  mode: ThemeMode.dark,
                  current: currentMode,
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final ThemeMode mode;
  final ThemeMode current;
  final IconData icon;
  final String label;

  const _ModeButton({
    required this.mode,
    required this.current,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = mode == current;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ThemeService.set(mode),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.75),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(
                        alpha: isDark ? 0.4 : 0.3,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? Colors.white
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : colorScheme.onSurfaceVariant,
                  letterSpacing: 0.2,
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
// INFO TILE (unchanged)
// ============================================================

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
    );
  }
}