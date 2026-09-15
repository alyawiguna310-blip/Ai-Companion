import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ai_companion/models/character.dart';

import '../ai_provider.dart';
import '../ai_types.dart';

class HuggingFaceProvider implements AIProvider {
  HuggingFaceProvider({
    required this.apiKey,
    this.model = 'openai/gpt-oss-120b:fastest',
  });

  static const String _baseUrl =
      'https://router.huggingface.co/v1/chat/completions';

  final String apiKey;
  final String model;

  @override
  String get name => 'Hugging Face';

  @override
  AIProviderType get type => AIProviderType.huggingface;

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
        'Hugging Face API key belum dikonfigurasi.',
      );
    }

    if (message.trim().isEmpty) {
      throw const AIServiceException(
        'Pesan tidak boleh kosong.',
      );
    }

    final messages = buildOpenAIMessagesList(
      message: message,
      history: history,
      systemPrompt: systemPrompt,
      character: character,
      extraSystemContext: extraSystemContext,
    );

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 1024,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      final decoded = decodeJsonResponse(response);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw AIServiceException(
          extractErrorMessage(decoded) ??
              'Hugging Face request gagal '
                  '(${response.statusCode}).',
        );
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AIServiceException(
          'Hugging Face tidak mengembalikan jawaban.',
        );
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map) {
        throw const AIServiceException(
          'Format response AI tidak valid.',
        );
      }

      final messageData = firstChoice['message'];
      if (messageData is! Map) {
        throw const AIServiceException(
          'Response message AI tidak valid.',
        );
      }

      final content = messageData['content'];
      if (content is! String ||
          content.trim().isEmpty) {
        throw const AIServiceException(
          'AI mengembalikan jawaban kosong.',
        );
      }

      return cleanOpenAIResponse(content);
    } on AIServiceException {
      rethrow;
    } on http.ClientException catch (error) {
      throw AIServiceException(
        'Tidak dapat terhubung ke Hugging Face: $error',
      );
    } on FormatException {
      throw const AIServiceException(
        'Response dari Hugging Face tidak dapat dibaca.',
      );
    } on Exception catch (error) {
      throw AIServiceException(
        'Terjadi kesalahan saat menghubungi AI: $error',
      );
    }
  }
}