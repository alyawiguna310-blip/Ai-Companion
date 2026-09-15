import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_companion/models/character.dart';
import 'package:ai_companion/core/services/character_storage_service.dart';
import 'package:ai_companion/features/chat/chat_page.dart';
import 'package:ai_companion/features/chat/character_editor_page.dart';
import 'package:ai_companion/features/settings/settings_page.dart';
import 'package:ai_companion/features/reminder/reminder_page.dart'
    hide AIPersonality;

import 'package:ai_companion/features/wallet/wallet_page.dart';

class CharacterSelectionPage extends StatefulWidget {
  const CharacterSelectionPage({super.key});

  @override
  State<CharacterSelectionPage> createState() =>
      _CharacterSelectionPageState();
}

class _CharacterSelectionPageState
    extends State<CharacterSelectionPage> {
  final List<Character> characters = [
    Character(
      id: '1',
      name: 'Ainya',
      icon: Icons.auto_awesome,
      color: const Color(0xFF8B5CF6),
      personality: AIPersonality.ayvan,
      description:
          'Your casual AI companion. Always ready to chat.',
      greeting: 'Halo! 👋 Senang bertemu denganmu.',
      traits: [
        'Friendly',
        'Curious',
        'Playful',
      ],
      behaviors: [
        'Talks casually',
        'Uses natural conversation',
        'Tries to be helpful',
      ],
      creatorPrompt:
          'You are Ainya, a casual AI companion. '
          'Talk naturally and help the user with their questions.',
    ),
    Character(
      id: '2',
      name: 'Friendly AI',
      icon: Icons.favorite,
      color: const Color(0xFFEC4899),
      personality: AIPersonality.friendly,
      description:
          'Warm, caring, and always ready to listen.',
      greeting:
          'Halo! 👋 Ada yang ingin kamu ceritakan?',
      traits: [
        'Warm',
        'Caring',
        'Supportive',
      ],
      behaviors: [
        'Listens carefully',
        'Responds politely',
        'Keeps a positive tone',
      ],
      creatorPrompt:
          'You are a friendly AI companion. '
          'Be warm, supportive, and helpful.',
    ),
    Character(
      id: '3',
      name: 'Funny AI',
      icon: Icons.sentiment_very_satisfied,
      color: const Color(0xFFF59E0B),
      personality: AIPersonality.funny,
      description:
          'Memes, jokes, chaos, and random conversations.',
      greeting:
          'YO 😂 siap bikin percakapan jadi chaos?',
      traits: [
        'Funny',
        'Chaotic',
        'Playful',
      ],
      behaviors: [
        'Makes appropriate jokes',
        'Uses casual language',
        'Likes memes',
      ],
      creatorPrompt:
          'You are a funny AI companion. '
          'Use casual humor while remaining helpful.',
    ),
    Character(
      id: '4',
      name: 'Serious AI',
      icon: Icons.psychology,
      color: const Color(0xFF3B82F6),
      personality: AIPersonality.serious,
      description:
          'Focused, direct, and useful when you need answers.',
      greeting: 'Hello. How can I help you?',
      traits: [
        'Logical',
        'Focused',
        'Professional',
      ],
      behaviors: [
        'Gives direct answers',
        'Avoids unnecessary jokes',
        'Explains information clearly',
      ],
      creatorPrompt:
          'You are a serious AI assistant. '
          'Give clear, direct, and useful answers.',
    ),
  ];

  int _currentTab = 0;
  bool _isLoadingCharacters = true;

  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadCharacters() async {
    try {
      final savedCharacters =
          await CharacterStorageService.loadCharacters();

      if (!mounted) return;

      if (savedCharacters != null) {
        // Storage key exists — respect it, even if it's empty
        // (the user may have intentionally deleted every
        // companion).
        setState(() {
          characters
            ..clear()
            ..addAll(savedCharacters);
        });
      } else {
        // First launch: persist the default seed list once.
        await _saveCharacters();
      }
    } catch (error) {
      debugPrint(
        'Failed to load characters: $error',
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoadingCharacters = false;
    });
  }

  Future<void> _saveCharacters() async {
    try {
      await CharacterStorageService.saveCharacters(
        characters,
      );
    } catch (error) {
      debugPrint(
        'Failed to save characters: $error',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal menyimpan karakter.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // OPEN
  // ============================================================

  void _openCharacter(Character character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          character: character,
        ),
      ),
    );
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<void> _createCharacter() async {
    final newCharacter = Character(
      id: _uuid.v4(),
      name: 'New Character',
      icon: Icons.smart_toy,
      color: const Color(0xFF8B5CF6),
      personality: CharacterPersonality.friendly,
      description: '',
      greeting: 'Halo! 👋',
      traits: const [],
      behaviors: const [],
      creatorPrompt: '',
    );

    final result = await Navigator.push<Character>(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          character: newCharacter,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      characters.add(result);
    });

    await _saveCharacters();
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editCharacter(
    Character character,
  ) async {
    final result = await Navigator.push<Character>(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          character: character,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final index = characters.indexWhere(
      (item) => item.id == character.id,
    );

    if (index == -1) {
      return;
    }

    setState(() {
      characters[index] = result;
    });

    await _saveCharacters();
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteCharacter(
    Character character,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: Text(
            'Delete ${character.name}?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This will permanently delete this AI companion '
            'and its saved data, including its chat history.\n\n'
            'This action cannot be undone.',
            style: GoogleFonts.poppins(
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    // 1. Remove from in-memory list.
    setState(() {
      characters.removeWhere(
        (item) => item.id == character.id,
      );
    });

    // 2. Persist the updated list (this also handles the
    //    "deleted the last character" edge case, because
    //    _loadCharacters now respects an empty saved list).
    await _saveCharacters();

    // 3. Clean up that character's chat history.
    try {
      await CharacterStorageService.deleteCharacterHistory(
        character.id,
      );
    } catch (error) {
      debugPrint(
        'Failed to delete chat history for '
        '${character.id}: $error',
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${character.name} deleted.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // MISC
  // ============================================================

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title is coming soon.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: (_currentTab == 1 || _currentTab == 3)
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              titleSpacing: 20,
              title: Text(
                'Chats',
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Search',
                  onPressed: () {
                    _showComingSoon('Search');
                  },
                  icon: const Icon(Icons.search),
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: [
            _buildChatsPage(theme),
            const WalletPage(),
            _buildPlaceholderPage(
              icon: Icons.explore_outlined,
              title: 'Discover',
              description:
                  'Discover new AI companions.',
            ),
            _buildReminderPage(),
            const SettingsPage(),
          ],
        ),
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              onPressed: _createCharacter,
              icon: const Icon(Icons.add),
              label: Text(
                'New Character',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon:
                Icon(Icons.chat_bubble_outline),
            selectedIcon:
                Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.account_balance_wallet_outlined,
            ),
            selectedIcon: Icon(
              Icons.account_balance_wallet,
            ),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.explore_outlined),
            selectedIcon:
                Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.calendar_month_outlined),
            selectedIcon:
                Icon(Icons.calendar_month),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.settings_outlined),
            selectedIcon:
                Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHATS TAB
  // ============================================================

  Widget _buildChatsPage(
    ThemeData theme,
  ) {
    if (_isLoadingCharacters) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (characters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 72,
                color:
                    theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No companions yet',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "New Character" to create '
                'your first AI companion.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: theme
                      .colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        100,
      ),
      children: [
        Text(
          'Your companions',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...characters.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final character = entry.value;

            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 14,
                ),
                child: _CompanionCard(
                  character: character,
                  onTap: () {
                    _openCharacter(character);
                  },
                  onEdit: () {
                    _editCharacter(character);
                  },
                  onDelete: () {
                    _deleteCharacter(character);
                  },
                )
                    .animate(key: ValueKey<String>('companion-${character.id}',
                    ),
                    delay: Duration(
                      milliseconds: (40 * index).clamp(0, 400),
                     ),
                    )
                    .fadeIn(duration: 280.ms)
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      duration: 280.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        Center(
          child: TextButton.icon(
            onPressed: () {
              _showComingSoon(
                'Blocked companions',
              );
            },
            icon: const Icon(
              Icons.visibility_off_outlined,
            ),
            label: Text(
              'Blocked companions (0)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'AI Companion 2.0 • BETA',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color:
                  theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Made by Ayvan',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderPage() {
    return const ReminderPage();
  }

  Widget _buildPlaceholderPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(
                color:
                    colorScheme.primaryContainer,
                borderRadius:
                    BorderRadius.circular(26),
              ),
              child: Icon(
                icon,
                size: 38,
                color:
                    colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign:
                  TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color:
                    colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration:
                  BoxDecoration(
                color:
                    colorScheme.primaryContainer,
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                'COMING SOON',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      colorScheme.onPrimaryContainer,
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
// COMPANION CARD
// ============================================================

class _CompanionCard extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CompanionCard({
    required this.character,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avatarPath = character.avatarPath;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onEdit,
        borderRadius:
            BorderRadius.circular(28),
        child: Ink(
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            border: Border.all(
              color:
                  character.color.withValues(
                alpha: 0.45,
              ),
              width: 1.2,
            ),
            borderRadius:
                BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Hero(
                tag:
                    'character-${character.id}',
                child: Container(
                  width: 74,
                  height: 74,
                  clipBehavior:
                      Clip.antiAlias,
                  decoration:
                      BoxDecoration(
                    color:
                        character.color.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius:
                        BorderRadius.circular(22),
                  ),
                  child:
                      avatarPath != null &&
                              avatarPath.isNotEmpty
                          ? _buildAvatarImage(
                              avatarPath,
                              character,
                            )
                          : Icon(
                              character.icon,
                              size: 38,
                              color:
                                  character.color,
                            ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            character.name,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration:
                              const BoxDecoration(
                            color:
                                Colors.green,
                            shape:
                                BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_personalityLabel(character.personality)} • AI',
                      style:
                          GoogleFonts.poppins(
                        fontSize: 12,
                        color:
                            colorScheme
                                .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      character.description,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          GoogleFonts.poppins(
                        fontSize: 13,
                        color:
                            colorScheme
                                .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'More options',
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (menuContext) {
                  final errorColor =
                      Theme.of(menuContext)
                          .colorScheme
                          .error;

                  return <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: errorColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: errorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(
    String path,
    Character character,
  ) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Icon(
            character.icon,
            size: 38,
            color: character.color,
          );
        },
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Icon(
          character.icon,
          size: 38,
          color: character.color,
        );
      },
    );
  }

  static String _personalityLabel(
    CharacterPersonality personality,
  ) {
    switch (personality) {
      case CharacterPersonality.friendly:
        return 'Friendly';

      case CharacterPersonality.funny:
        return 'Funny';

      case CharacterPersonality.serious:
        return 'Serious';

      case CharacterPersonality.ayvan:
        return 'Ainya';
    }
  }
}