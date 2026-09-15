import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_companion/models/character.dart';

class CharacterStorageService {
  static const String _charactersKey =
      'ai_companion_characters';

  /// Prefix used by [ChatPage] to persist per-character chat history.
  ///
  /// Kept here so character-scoped storage lives in one place.
  static const String _chatHistoryKeyPrefix =
      'chat_history_';

  // ============================================================
  // SAVE CHARACTERS
  // ============================================================

  static Future<void> saveCharacters(
    List<Character> characters,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final data = characters
        .map(
          (character) =>
              _characterToJson(character),
        )
        .toList();

    await prefs.setString(
      _charactersKey,
      jsonEncode(data),
    );
  }

  // ============================================================
  // LOAD CHARACTERS
  // ============================================================

  static Future<List<Character>?>
      loadCharacters() async {
    final prefs =
        await SharedPreferences.getInstance();

    final raw =
        prefs.getString(_charactersKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded =
          jsonDecode(raw);

      if (decoded is! List) {
        return null;
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                _characterFromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // CLEAR CHARACTERS
  // ============================================================

  static Future<void> clearCharacters() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _charactersKey,
    );
  }

  // ============================================================
  // DELETE CHARACTER-SCOPED CHAT HISTORY
  // ============================================================

  /// Removes the persisted chat history for [characterId].
  ///
  /// Called when a companion is deleted so no orphaned
  /// conversation data is left behind in SharedPreferences.
  static Future<void> deleteCharacterHistory(
    String characterId,
  ) async {
    if (characterId.isEmpty) return;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      '$_chatHistoryKeyPrefix$characterId',
    );
  }

  // ============================================================
  // CHARACTER -> JSON
  // ============================================================

  static Map<String, dynamic> _characterToJson(
    Character character,
  ) {
    return {
      'id': character.id,

      'name': character.name,

      'avatarPath':
          character.avatarPath,

      'iconName':
          _iconName(character.icon),

      'color':
          character.color.toARGB32(),

      'personality':
          character.personality.name,

      'description':
          character.description,

      'greeting':
          character.greeting,

      'traits':
          character.traits,

      'behaviors':
          character.behaviors,

      'creatorPrompt':
          character.creatorPrompt,
    };
  }

  // ============================================================
  // JSON -> CHARACTER
  // ============================================================

  static Character _characterFromJson(
    Map<String, dynamic> json,
  ) {
    return Character(
      id:
          json['id']?.toString() ??
              '',

      name:
          json['name']?.toString() ??
              'Unknown',

      avatarPath:
          json['avatarPath']
              ?.toString(),

      icon:
          _iconFromJson(json),

      color:
          _colorFromJson(json),

      personality:
          _personalityFromString(
        json['personality']
            ?.toString(),
      ),

      description:
          json['description']
                  ?.toString() ??
              '',

      greeting:
          json['greeting']
                  ?.toString() ??
              'Halo! 👋',

      traits:
          _stringList(
        json['traits'],
      ),

      behaviors:
          _stringList(
        json['behaviors'],
      ),

      creatorPrompt:
          json['creatorPrompt']
                  ?.toString() ??
              '',
    );
  }

  // ============================================================
  // PERSONALITY
  // ============================================================

  static CharacterPersonality
      _personalityFromString(
    String? value,
  ) {
    switch (value) {
      case 'friendly':
        return CharacterPersonality.friendly;

      case 'funny':
        return CharacterPersonality.funny;

      case 'serious':
        return CharacterPersonality.serious;

      case 'ayvan':
        return CharacterPersonality.ayvan;

      default:
        return CharacterPersonality.friendly;
    }
  }

  // ============================================================
  // ICON -> NAME
  // ============================================================

  static String _iconName(
    IconData icon,
  ) {
    if (icon == Icons.favorite) {
      return 'favorite';
    }

    if (icon ==
        Icons.sentiment_very_satisfied) {
      return 'sentiment_very_satisfied';
    }

    if (icon == Icons.psychology) {
      return 'psychology';
    }

    if (icon == Icons.auto_awesome) {
      return 'auto_awesome';
    }

    if (icon == Icons.smart_toy) {
      return 'smart_toy';
    }

    if (icon ==
        Icons.notifications_active) {
      return 'notifications_active';
    }

    if (icon == Icons.person) {
      return 'person';
    }

    if (icon == Icons.chat) {
      return 'chat';
    }

    if (icon == Icons.star) {
      return 'star';
    }

    return 'smart_toy';
  }

  // ============================================================
  // NAME -> ICON
  // ============================================================

  static IconData _iconFromJson(
    Map<String, dynamic> json,
  ) {
    final iconName =
        json['iconName']?.toString();

    switch (iconName) {
      case 'favorite':
        return Icons.favorite;

      case 'sentiment_very_satisfied':
        return Icons.sentiment_very_satisfied;

      case 'psychology':
        return Icons.psychology;

      case 'auto_awesome':
        return Icons.auto_awesome;

      case 'smart_toy':
        return Icons.smart_toy;

      case 'notifications_active':
        return Icons.notifications_active;

      case 'person':
        return Icons.person;

      case 'chat':
        return Icons.chat;

      case 'star':
        return Icons.star;

      default:
        return Icons.smart_toy;
    }
  }

  // ============================================================
  // COLOR
  // ============================================================

  static Color _colorFromJson(
    Map<String, dynamic> json,
  ) {
    final value =
        json['color'];

    if (value is int) {
      return Color(value);
    }

    return Colors.purple;
  }

  // ============================================================
  // STRING LIST
  // ============================================================

  static List<String> _stringList(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) =>
              item.toString(),
        )
        .where(
          (item) =>
              item.isNotEmpty,
        )
        .toList();
  }
}