import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ai_companion/models/character.dart';

import '../ai_provider.dart';
import '../ai_types.dart';

class CloudflareProvider implements AIProvider {
  CloudflareProvider({
    required this.apiToken,
    required this.accountId,
    this.model = '@cf/openai/gpt-oss-120b',
  });

  static const String _apiBase =
      'https://api.cloudflare.com/client/v4/accounts';

  final String apiToken;
  final String accountId;
  final String model;

  @override
  String get name => 'Cloudflare Workers AI';

  @override
  AIProviderType get type => AIProviderType.cloudflare;

  @override
  Future<String> sendMessage({
    required String message,
    List<AIChatMessage> history = const [],
    String? systemPrompt,
    Character? character,
    String? extraSystemContext,
  }) async {
    if (apiToken.trim().isEmpty) {
      throw const AIServiceException(
        'Cloudflare API token belum dikonfigurasi.',
      );
    }

    if (accountId.trim().isEmpty) {
      throw const AIServiceException(
        'Cloudflare account ID belum dikonfigurasi.',
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

    final url =
        '$_apiBase/${accountId.trim()}/ai/v1/chat/completions';

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization':
                  'Bearer ${apiToken.trim()}',
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
              'Cloudflare request gagal '
                  '(${response.statusCode}).',
        );
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AIServiceException(
          'Cloudflare tidak mengembalikan jawaban.',
        );
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map) {
        throw const AIServiceException(
          'Format response Cloudflare tidak valid.',
        );
      }

      final messageData = firstChoice['message'];
      if (messageData is! Map) {
        throw const AIServiceException(
          'Response message Cloudflare tidak valid.',
        );
      }

      final content = messageData['content'];
      if (content is! String ||
          content.trim().isEmpty) {
        throw const AIServiceException(
          'Cloudflare mengembalikan jawaban kosong.',
        );
      }

      return cleanOpenAIResponse(content);
    } on AIServiceException {
      rethrow;
    } on http.ClientException catch (error) {
      throw AIServiceException(
        'Tidak dapat terhubung ke Cloudflare: $error',
      );
    } on FormatException {
      throw const AIServiceException(
        'Response dari Cloudflare tidak dapat dibaca.',
      );
    } on Exception catch (error) {
      throw AIServiceException(
        'Terjadi kesalahan saat menghubungi Cloudflare: $error',
      );
    }
  }
}