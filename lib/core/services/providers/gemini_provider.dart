import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ai_companion/models/character.dart';

import '../ai_provider.dart';
import '../ai_types.dart';

class GeminiProvider implements AIProvider {
  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-3.6-flash',
  });

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final String apiKey;
  final String model;

  @override
  String get name => 'Google Gemini';

  @override
  AIProviderType get type => AIProviderType.gemini;

  @override
  Future<String> sendMessage({
    required String message,
    List<AIChatMessage> history = const [],
    String? systemPrompt,
    Character? character,
    String? extraSystemContext,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AIServiceException(
        'Gemini API key belum dikonfigurasi.',
      );
    }

    if (message.trim().isEmpty) {
      throw const AIServiceException(
        'Pesan tidak boleh kosong.',
      );
    }

    // ---------------------------------------------------------
    // SYSTEM INSTRUCTION (character + extra context, merged)
    // ---------------------------------------------------------
    final systemParts = <String>[];

    if (character != null) {
      systemParts.add(buildCharacterPrompt(character));
    } else if (systemPrompt != null &&
        systemPrompt.trim().isNotEmpty) {
      systemParts.add(systemPrompt.trim());
    }

    if (extraSystemContext != null &&
        extraSystemContext.trim().isNotEmpty) {
      systemParts.add(extraSystemContext.trim());
    }

    // ---------------------------------------------------------
    // CONTENTS (Gemini uses roles "user" | "model")
    // ---------------------------------------------------------
    final contents = <Map<String, dynamic>>[];

    for (final item in history) {
      if (item.content.trim().isEmpty) continue;

      final role = item.role.toLowerCase();

      // Gemini does not accept a "system" role inside contents —
      // those are handled via systemInstruction above.
      if (role == 'system') continue;

      contents.add({
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': item.content.trim()},
        ],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': message.trim()},
      ],
    });

    // ---------------------------------------------------------
    // BODY
    // ---------------------------------------------------------
    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    };

    if (systemParts.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemParts.join('\n\n')},
        ],
      };
    }

    final url = '$_baseUrl/$model:generateContent';

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey.trim(),
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      final decoded = decodeJsonResponse(response);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw AIServiceException(
          extractErrorMessage(decoded) ??
              'Gemini request gagal '
                  '(${response.statusCode}).',
        );
      }

      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const AIServiceException(
          'Gemini tidak mengembalikan jawaban.',
        );
      }

      final firstCandidate = candidates.first;
      if (firstCandidate is! Map) {
        throw const AIServiceException(
          'Format response Gemini tidak valid.',
        );
      }

      final content = firstCandidate['content'];
      if (content is! Map) {
        throw const AIServiceException(
          'Response content Gemini tidak valid.',
        );
      }

      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) {
        throw const AIServiceException(
          'Gemini tidak mengembalikan teks.',
        );
      }

      final buffer = StringBuffer();
      for (final part in parts) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text'] as String);
        }
      }

      final result = buffer.toString().trim();
      if (result.isEmpty) {
        throw const AIServiceException(
          'Gemini mengembalikan jawaban kosong.',
        );
      }

      return result;
    } on AIServiceException {
      rethrow;
    } on http.ClientException catch (error) {
      throw AIServiceException(
        'Tidak dapat terhubung ke Gemini: $error',
      );
    } on FormatException {
      throw const AIServiceException(
        'Response dari Gemini tidak dapat dibaca.',
      );
    } on Exception catch (error) {
      throw AIServiceException(
        'Terjadi kesalahan saat menghubungi Gemini: $error',
      );
    }
  }
}