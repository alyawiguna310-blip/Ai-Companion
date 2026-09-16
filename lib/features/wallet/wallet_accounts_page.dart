import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/wallet_account_storage_service.dart';
import '../../core/services/wallet_storage_service.dart';
import '../../models/wallet_account.dart';

class WalletAccountsPage extends StatefulWidget {
  const WalletAccountsPage({super.key});

  @override
  State<WalletAccountsPage> createState() =>
      _WalletAccountsPageState();
}

class _WalletAccountsPageState extends State<WalletAccountsPage> {
  List<WalletAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await WalletAccountStorageService.load();
    if (!mounted) return;
    setState(() {
      _accounts = list;
      _isLoading = false;
    });
  }

  Future<void> _addAccount() async {
    final created = await showModalBottomSheet<WalletAccount>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddAccountSheet(),
    );

    if (created == null || !mounted) return;

    final updated =
        await WalletAccountStorageService.add(created);
    if (!mounted) return;
    setState(() => _accounts = updated);
  }

  Future<void> _editAccount(WalletAccount account) async {
    final edited = await showModalBottomSheet<WalletAccount>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddAccountSheet(existing: account),
    );

    if (edited == null || !mounted) return;

    final updated =
        await WalletAccountStorageService.update(edited);
    if (!mounted) return;
    setState(() => _accounts = updated);
  }

  Future<void> _deleteAccount(WalletAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          'Delete ${account.name}?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Transactions in this account will remain in storage '
          'but won\'t be visible until you re-add an account '
          'with the same ID.\n\n'
          'This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
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

    if (confirmed != true || !mounted) return;

    final updated =
        await WalletAccountStorageService.remove(account.id);
    if (!mounted) return;
    setState(() => _accounts = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Accounts',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAccount,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Account',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Text(
                  'Tap an account to edit. Long-press to delete.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                ..._accounts.map(
                  (account) => _AccountTile(
                    account: account,
                    onTap: () => _editAccount(account),
                    onDelete: () => _deleteAccount(account),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final WalletAccount account;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AccountTile({
    required this.account,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List>(
      future: WalletStorageService.loadForAccount(account.id),
      builder: (context, snapshot) {
        final txs = snapshot.data ?? const [];
        var balance = 0;
        for (final tx in txs) {
          balance += (tx as dynamic).signedAmount as int;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onDelete,
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        account.color.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            account.color
                                .withValues(alpha: 0.22),
                            account.color
                                .withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      child: Icon(
                        account.icon,
                        color: account.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${txs.length} transaction'
                            '${txs.length == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: theme
                                  .colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatRupiah(balance),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: balance >= 0
                            ? Colors.green.shade700
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatRupiah(int amount) {
    final isNeg = amount < 0;
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return '${isNeg ? '-' : ''}Rp $buffer';
  }
}

// ============================================================
// ADD / EDIT SHEET
// ============================================================

class _AddAccountSheet extends StatefulWidget {
  final WalletAccount? existing;

  const _AddAccountSheet({this.existing});

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  late TextEditingController _nameController;
  late IconData _icon;
  late Color _color;

  final List<Color> _palette = const [
    Color(0xFF6C5CE7),
    Color(0xFF0984E3),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFFD63031),
    Color(0xFFFDCB6E),
    Color(0xFF8E44AD),
    Color(0xFF00CEC9),
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(
      text: existing?.name ?? '',
    );
    _icon = existing?.icon ??
        WalletAccount.availableIcons.first;
    _color = existing?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final result = widget.existing?.copyWith(
          name: name,
          icon: _icon,
          color: _color,
        ) ??
        WalletAccount(
          id: DateTime.now()
              .microsecondsSinceEpoch
              .toString(),
          name: name,
          icon: _icon,
          color: _color,
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
              widget.existing == null
                  ? 'New Account'
                  : 'Edit Account',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Account name',
                hintText: 'e.g. Personal, Business',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Icon',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: WalletAccount.availableIcons
                  .map(
                    (icon) => GestureDetector(
                      onTap: () => setState(() => _icon = icon),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _icon == icon
                              ? _color.withValues(alpha: 0.2)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: _icon == icon
                                ? _color
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: _icon == icon
                              ? _color
                              : theme
                                  .colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Color',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _palette
                  .map(
                    (c) => GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 36,
                        height: 36,
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
                  widget.existing == null
                      ? 'Create'
                      : 'Save',
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