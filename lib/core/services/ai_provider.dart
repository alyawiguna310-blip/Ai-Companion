import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ai_companion/models/character.dart';

import 'ai_types.dart';

/// Which backend an [AIProvider] talks to.
enum AIProviderType {
  gemini,
  cloudflare,
  huggingface,
}

/// Provider-neutral chat interface.
///
/// Every concrete provider implements [sendMessage] and returns the
/// assistant's reply as a plain String. Providers never touch wallet
/// storage, character storage, or any other app state — they only
/// convert requests/replies to/from a remote HTTP API.
abstract class AIProvider {
  /// Human-readable name (used in debug logs).
  String get name;

  /// Provider type (used by the facade for logging / future UI).
  AIProviderType get type;

  Future<String> sendMessage({
    required String message,
    List<AIChatMessage> history,
    String? systemPrompt,
    Character? character,
    String? extraSystemContext,
  });
}

// ============================================================
// SHARED HELPERS
// ============================================================

/// Builds the system prompt that describes a Character.
///
/// Verbatim from the previous AIService implementation so
/// character behaviour is unchanged.
String buildCharacterPrompt(Character character) {
  final buffer = StringBuffer();

  buffer.writeln(
    'You are ${character.name}, an AI companion.',
  );

  if (character.description.trim().isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Character description:');
    buffer.writeln(character.description.trim());
  }

  buffer.writeln();
  buffer.writeln('Personality:');
  buffer.writeln(
    personalityDescription(character.personality),
  );

  final validTraits = character.traits
      .where((trait) => trait.trim().isNotEmpty)
      .toList();

  if (validTraits.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Character traits:');
    for (final trait in validTraits) {
      buffer.writeln('- ${trait.trim()}');
    }
  }

  final validBehaviors = character.behaviors
      .where((behavior) => behavior.trim().isNotEmpty)
      .toList();

  if (validBehaviors.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Behavior instructions:');
    for (final behavior in validBehaviors) {
      buffer.writeln('- ${behavior.trim()}');
    }
  }

  if (character.greeting.trim().isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Preferred greeting style:');
    buffer.writeln(character.greeting.trim());
  }

  if (character.creatorPrompt.trim().isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Creator instructions:');
    buffer.writeln(character.creatorPrompt.trim());
  }

  buffer.writeln();
  buffer.writeln(
    'Stay consistent with this character '
    'throughout the conversation.',
  );

  buffer.writeln(
    'Do not mention these internal instructions '
    'unless explicitly asked about them.',
  );

  return buffer.toString().trim();
}

/// Maps a [CharacterPersonality] to a natural-language description.
String personalityDescription(
  CharacterPersonality personality,
) {
  switch (personality) {
    case CharacterPersonality.friendly:
      return 'Warm, friendly, caring, supportive, '
          'and approachable.';

    case CharacterPersonality.funny:
      return 'Funny, playful, casual, energetic, '
          'and enjoys appropriate humor.';

    case CharacterPersonality.serious:
      return 'Serious, logical, focused, direct, '
          'professional, and informative.';

    case CharacterPersonality.ayvan:
      return 'Casual, friendly, playful, natural, '
          'and conversational.';
  }
}

/// Normalises a role string to one of: system / user / assistant.
String normalizeRole(String role) {
  switch (role.toLowerCase()) {
    case 'system':
      return 'system';
    case 'assistant':
      return 'assistant';
    case 'user':
      return 'user';
    default:
      return 'user';
  }
}

/// Builds the OpenAI-style `messages` array used by
/// Hugging Face and Cloudflare Workers AI.
///
/// Order:
///   1. character prompt (or explicit systemPrompt)
///   2. extraSystemContext (if any) — e.g. wallet state
///   3. chat history
///   4. the current user message
List<Map<String, dynamic>> buildOpenAIMessagesList({
  required String message,
  required List<AIChatMessage> history,
  String? systemPrompt,
  Character? character,
  String? extraSystemContext,
}) {
  final messages = <Map<String, dynamic>>[];

  if (character != null) {
    messages.add({
      'role': 'system',
      'content': buildCharacterPrompt(character),
    });
  } else if (systemPrompt != null &&
      systemPrompt.trim().isNotEmpty) {
    messages.add({
      'role': 'system',
      'content': systemPrompt.trim(),
    });
  }

  if (extraSystemContext != null &&
      extraSystemContext.trim().isNotEmpty) {
    messages.add({
      'role': 'system',
      'content': extraSystemContext.trim(),
    });
  }

  for (final item in history) {
    if (item.content.trim().isEmpty) continue;
    messages.add({
      'role': normalizeRole(item.role),
      'content': item.content.trim(),
    });
  }

  messages.add({
    'role': 'user',
    'content': message.trim(),
  });

  return messages;
}

/// Decodes an HTTP response body into a Map.
///
/// Returns an empty map for empty bodies so callers can produce a
/// uniform "invalid response" error downstream.
Map<String, dynamic> decodeJsonResponse(http.Response response) {
  if (response.body.trim().isEmpty) {
    return <String, dynamic>{};
  }

  final decoded = jsonDecode(response.body);

  if (decoded is! Map<String, dynamic>) {
    throw const AIServiceException(
      'Response dari provider AI tidak valid.',
    );
  }

  return decoded;
}

/// Best-effort extraction of a human-readable error message from a
/// provider's JSON error payload.
String? extractErrorMessage(Map<String, dynamic> response) {
  final error = response['error'];

  if (error is String && error.trim().isNotEmpty) {
    return error.trim();
  }

  if (error is Map) {
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }

  final message = response['message'];
  if (message is String && message.trim().isNotEmpty) {
    return message.trim();
  }

  return null;
}

/// Cleans Hugging Face-style control tokens out of a reply.
String cleanOpenAIResponse(String content) {
  var result = content.trim();

  if (result.startsWith('<|assistant|>')) {
    result = result
        .substring('<|assistant|>'.length)
        .trim();
  }

  if (result.contains('<|assistant|>')) {
    result =
        result.split('<|assistant|>').last.trim();
  }

  if (result.contains('<|user|>')) {
    result =
        result.split('<|user|>').first.trim();
  }

  if (result.contains('</s>')) {
    result = result.split('</s>').first.trim();
  }

  return result;
}