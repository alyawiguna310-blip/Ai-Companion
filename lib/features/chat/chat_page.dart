import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/ai_service.dart';
import '../../core/services/wallet_action_service.dart';
import '../../models/character.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'time': time.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      time: DateTime.tryParse(
            json['time']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class ChatPage extends StatefulWidget {
  final Character character;

  const ChatPage({
    super.key,
    required this.character,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final FocusNode _inputFocusNode = FocusNode();

  final List<ChatMessage> _messages = [];

  late final AIService _aiService;

  bool _isTyping = false;
  bool _isLoadingHistory = true;

  Character get character => widget.character;

  String get _historyKey =>
      'chat_history_${character.id}';

  @override
  void initState() {
    super.initState();

    // Provider selection (Gemini → Cloudflare → Hugging Face)
    // is handled inside AIService.fromEnvironment().
    _aiService = AIService.fromEnvironment();
    
    _loadHistory();
  }

  // ============================================================
  // LOAD HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is List && decoded.isNotEmpty) {
          final loaded = decoded
              .whereType<Map>()
              .map(
                (item) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where(
                (message) => message.text.trim().isNotEmpty,
              )
              .toList();

          if (loaded.isNotEmpty && mounted) {
            setState(() {
              _messages
                ..clear()
                ..addAll(loaded);
              _isLoadingHistory = false;
            });

            _scrollToBottom();
            return;
          }
        }
      }
    } catch (error) {
      debugPrint('Failed to load chat history: $error');
    }

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            text: _initialGreeting(),
            isUser: false,
          ),
        );
      _isLoadingHistory = false;
    });
  }

  // ============================================================
  // SAVE HISTORY
  // ============================================================

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = _messages
          .map((message) => message.toJson())
          .toList();

      await prefs.setString(
        _historyKey,
        jsonEncode(data),
      );
    } catch (error) {
      debugPrint('Failed to save chat history: $error');
    }
  }

  // ============================================================
  // CLEAR HISTORY STORAGE
  // ============================================================

  Future<void> _clearHistoryStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (error) {
      debugPrint('Failed to clear chat history: $error');
    }
  }

  // ============================================================
  // INITIAL GREETING
  // ============================================================

  String _initialGreeting() {
    if (character.greeting.trim().isNotEmpty) {
      return character.greeting.trim();
    }

    switch (character.personality) {
      case CharacterPersonality.friendly:
        return 'Hai! Aku ${character.name}. '
            'Senang bisa ngobrol dengan kamu.';

      case CharacterPersonality.funny:
        return 'YO! Aku ${character.name}! '
            'Siap bikin obrolan jadi seru 😎';

      case CharacterPersonality.serious:
        return 'Halo. Saya ${character.name}. '
            'Ada yang bisa saya bantu?';

      case CharacterPersonality.ayvan:
        return 'Bro 😎 Aku ${character.name}. '
            'Gas ngobrol!';
    }
  }

  // ============================================================
  // BUILD HISTORY FOR AI
  // ============================================================

  List<AIChatMessage> _buildHistoryForAI() {
    if (_messages.isEmpty) {
      return const [];
    }

    final historyMessages = List<ChatMessage>.from(_messages);

    if (historyMessages.isNotEmpty &&
        historyMessages.last.isUser) {
      historyMessages.removeLast();
    }

    const maxHistory = 24;
    if (historyMessages.length > maxHistory) {
      return historyMessages
          .sublist(historyMessages.length - maxHistory)
          .map((message) {
        if (message.isUser) {
          return AIChatMessage.user(message.text);
        }
        return AIChatMessage.assistant(message.text);
      }).toList();
    }

    return historyMessages.map((message) {
      if (message.isUser) {
        return AIChatMessage.user(message.text);
      }
      return AIChatMessage.assistant(message.text);
    }).toList();
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isTyping) {
      return;
    }

    _messageController.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
        ),
      );
      _isTyping = true;
    });

    await _saveHistory();
    _scrollToBottom();

    try {
      final history = _buildHistoryForAI();

      // Wallet state is refreshed on every send so the AI
      // always sees the current balance.

      final walletContext =
          await WalletActionService.buildContext();

      final response = await _aiService.sendMessage(
        message: text,
        history: history,
        character: character,
        extraSystemContext: walletContext,
      );

      if (!mounted) return;

      final parsed =
          WalletActionService.parseResponse(response);

      if (parsed.hasAction) {
        await _handleWalletAction(parsed);
        return;
      }

      final displaytext = parsed.cleanText.isNotEmpty
          ? parsed.cleanText
          : response;

      setState(() {
        _messages.add(
          ChatMessage(
            text: displaytext,
            isUser: false,
          ),
        );
        _isTyping = false;
      });

      await _saveHistory();
    } on AIServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: '⚠️ ${error.message}',
            isUser: false,
          ),
        );
        _isTyping = false;
      });

      await _saveHistory();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text:
                '⚠️ Terjadi kesalahan yang tidak terduga.\n\n$error',
            isUser: false,
          ),
        );
        _isTyping = false;
      });

      await _saveHistory();
    }

    _scrollToBottom();
  }

   // ============================================================
  // WALLET ACTION HANDLING
  // ============================================================

  Future<void> _handleWalletAction(
    WalletActionResult parsed,
  ) async {
    final action = parsed.action;
    if (action == null) return;

    // 1. Show the AI's natural text (if any) first.
    if (parsed.cleanText.isNotEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: parsed.cleanText,
            isUser: false,
          ),
        );
      });
      await _saveHistory();
    }

    // 2. Confirm if the amount is above the threshold.
    final needsConfirmation = action.amount >=
        WalletActionService.confirmationThreshold;

    if (needsConfirmation) {
      final confirmed =
          await _showWalletConfirmDialog(action);

      if (!mounted) return;

      if (confirmed != true) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Transaction cancelled.',
              isUser: false,
            ),
          );
          _isTyping = false;
        });
        await _saveHistory();
        _scrollToBottom();
        return;
      }
    }

    // 3. Execute the action.
    try {
      final tx = await WalletActionService.execute(action);

      if (!mounted) return;

      final sign = tx.isIncome ? '+' : '-';
      final amountStr = WalletActionService.formatRupiah(
        tx.amount,
      );

      final typeLabel =
          tx.isIncome ? 'Income' : 'Expense';

      final buffer = StringBuffer()
        ..writeln('✅ $typeLabel recorded')
        ..write('$sign$amountStr • ${tx.category}');

      if (tx.description.trim().isNotEmpty) {
        buffer.write('\n${tx.description.trim()}');
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text: buffer.toString(),
            isUser: false,
          ),
        );
        _isTyping = false;
      });

      await _saveHistory();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: '⚠️ Gagal mencatat transaksi: $error',
            isUser: false,
          ),
        );
        _isTyping = false;
      });

      await _saveHistory();
    }

    _scrollToBottom();
  }

  Future<bool?> _showWalletConfirmDialog(
    WalletAction action,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        final isExpense = action.isExpense;
        final sign = isExpense ? '-' : '+';
        final color = isExpense
            ? colorScheme.error
            : Colors.green.shade700;

        return AlertDialog(
          title: Text(
            isExpense
                ? 'Confirm expense?'
                : 'Confirm income?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$sign${WalletActionService.formatRupiah(action.amount)}',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Category: ${action.category}',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              if (action.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Note: ${action.description}',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'This transaction will be recorded in your wallet.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // CHAT OPTIONS
  // ============================================================

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear conversation'),
                subtitle: const Text(
                  'Remove all messages from this conversation',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clearConversation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('About ${character.name}'),
                subtitle: Text(
                  '${character.name} • AI Companion v2.0 Beta',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // CLEAR CONVERSATION
  // ============================================================

  Future<void> _clearConversation() async {
    await _clearHistoryStorage();

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            text:
                '${_initialGreeting()}\n\nPercakapan baru dimulai.',
            isUser: false,
          ),
        );
    });

    await _saveHistory();
    _scrollToBottom();
  }

  // ============================================================
  // ABOUT
  // ============================================================

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              _CharacterAvatar(
                character: character,
                size: 42,
                borderRadius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(character.name),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              '${character.name}\n\n'
              '${character.description}\n\n'
              'Traits: '
              '${character.traits.isEmpty ? "Not specified" : character.traits.join(", ")}\n\n'
              'Behaviors: '
              '${character.behaviors.isEmpty ? "Not specified" : character.behaviors.join(", ")}\n\n'
              'AI Companion v2.0 Beta',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SUGGESTION
  // ============================================================

  void _insertSuggestion(String text) {
    _messageController.text = text;
    _messageController.selection =
        TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    _inputFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            _CharacterAvatar(
              character: character,
              size: 42,
              borderRadius: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'AI Companion • BETA',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chat options',
            onPressed: _showChatOptions,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingHistory
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _messages.length <= 1
                        ? _buildWelcomeState(theme)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              20,
                              16,
                              20,
                            ),
                            itemCount: _messages.length +
                                (_isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isTyping &&
                                  index == _messages.length) {
                                return _TypingIndicator(
                                  character: character,
                                );
                              }

                              final message = _messages[index];

                              // Stable key so the animation runs once per message, not on
                              // every parent rebuild.
                              final stableKey = ValueKey<String>(
                                'msg-${message.time.microsecondsSinceEpoch}-'
                                '${message.isUser ? 'u' : 'a'}',
                              );

                              return RepaintBoundary(
                                child: _MessageBubble(
                                  message: message,
                                  character: character,
                              )
                                  .animate(key: stableKey)
                                  .fadeIn(duration: 220.ms)
                                  .slideY(
                                    begin: 0.06,
                                    end: 0,
                                    duration: 220.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
                              );
                            },
                          ),
                  ),
                  _buildInputArea(theme),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcomeState(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: character.color.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _CharacterAvatar(
              character: character,
              size: 90,
              borderRadius: 30,
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1, 1),
                duration: 300.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 24),
          Text(
            'Hi, I\'m ${character.name} 👋',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 250.ms),
          const SizedBox(height: 8),
          Text(
            character.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ).animate().fadeIn(delay: 120.ms, duration: 250.ms),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              'VERSION 2.0 • BETA',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ).animate().fadeIn(delay: 160.ms, duration: 250.ms),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking me something',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            icon: Icons.chat_bubble_outline,
            text: 'Tell me about yourself',
            onTap: () {
              _insertSuggestion('Tell me about yourself');
            },
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 10),
          _SuggestionCard(
            icon: Icons.lightbulb_outline,
            text: 'Give me something interesting',
            onTap: () {
              _insertSuggestion('Give me something interesting');
            },
          ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 10),
          _SuggestionCard(
            icon: Icons.notifications_none,
            text: 'Help me remember something',
            onTap: () {
              _insertSuggestion('Help me remember something');
            },
          ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 30),
          Text(
            'Character personality is configured by the creator.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInputArea(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Attachments',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Attachments akan tersedia pada versi berikutnya.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                textInputAction: TextInputAction.newline,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Message ${character.name}...',
                  hintStyle: GoogleFonts.poppins(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;

              return IconButton.filled(
                tooltip: 'Send',
                onPressed: hasText && !_isTyping ? _sendMessage : null,
                icon: const Icon(Icons.arrow_upward),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CHARACTER AVATAR
// ============================================================

class _CharacterAvatar extends StatelessWidget {
  final Character character;
  final double size;
  final double borderRadius;

  const _CharacterAvatar({
    required this.character,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final path = character.avatarPath;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: character.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: path != null && path.isNotEmpty
          ? _buildImage(path)
          : Icon(
              character.icon,
              size: size * 0.48,
              color: character.color,
            ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            character.icon,
            size: size * 0.48,
            color: character.color,
          );
        },
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          character.icon,
          size: size * 0.48,
          color: character.color,
        );
      },
    );
  }
}

// ============================================================
// MESSAGE BUBBLE
// ============================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Character character;

  const _MessageBubble({
    required this.message,
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 330),
          margin: const EdgeInsets.only(bottom: 14, left: 45),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Text(
            message.text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onPrimary,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 14, right: 30),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CharacterAvatar(
              character: character,
              size: 34,
              borderRadius: 11,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Text(
                  message.text,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface,
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
// TYPING INDICATOR
// ============================================================

class _TypingIndicator extends StatelessWidget {
  final Character character;

  const _TypingIndicator({
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 30),
        child: Row(
          children: [
            _CharacterAvatar(
              character: character,
              size: 34,
              borderRadius: 11,
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  _Dot(color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  _Dot(color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ============================================================
// DOT
// ============================================================

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ============================================================
// SUGGESTION CARD
// ============================================================

class _SuggestionCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}