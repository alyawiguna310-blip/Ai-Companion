import 'package:flutter/foundation.dart';

import 'package:ai_companion/models/character.dart';

import 'ai_provider.dart';
import 'ai_types.dart';
import 'providers/cloudflare_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/huggingface_provider.dart';

// Re-export public types so existing imports of
//   `package:ai_companion/core/services/ai_service.dart`
// continue to see AIServiceException and AIChatMessage.
export 'ai_types.dart';

/// Provider-neutral façade over the underlying AI backend.
///
/// The rest of the app should only talk to [AIService]. It never
/// matters which provider is active.
///
/// Two ways to construct:
///   • `AIService.fromEnvironment()` — preferred; picks the provider
///     based on `--dart-define` keys. See docs below.
///   • `AIService(apiKey: ...)` — legacy Hugging Face shortcut,
///     kept for backward compatibility.
class AIService {
  final AIProvider _provider;

  AIService._(this._provider);

  /// Name of the active provider, useful for debug UI.
  String get providerName => _provider.name;

  /// Type of the active provider.
  AIProviderType get providerType => _provider.type;

  // ============================================================
  // FACTORIES
  // ============================================================

  /// Legacy Hugging Face shortcut.
  ///
  /// Preserved verbatim so existing callers keep working.
  factory AIService({
    required String apiKey,
    String model = 'openai/gpt-oss-120b:fastest',
  }) {
    return AIService._(
      HuggingFaceProvider(apiKey: apiKey, model: model),
    );
  }

  /// Builds an [AIService] from compile-time `--dart-define` values.
  ///
  /// Priority order:
  ///   1. GEMINI_API_KEY
  ///   2. CF_API_TOKEN + CF_ACCOUNT_ID
  ///   3. HF_API_KEY
  ///   4. (none) — returns a Hugging Face provider with an empty
  ///      key, which throws a clear error on first use.
  ///
  /// Optional overrides (all via `--dart-define`):
  ///   GEMINI_MODEL   default: gemini-2.5-flash
  ///   CF_MODEL       default: @cf/openai/gpt-oss-120b
  ///   HF_MODEL       default: openai/gpt-oss-120b:fastest
  ///
  /// Example:
  ///   flutter run \
  ///     --dart-define=GEMINI_API_KEY=AIza...
  factory AIService.fromEnvironment() {
    const geminiKey =
        String.fromEnvironment('GEMINI_API_KEY');
    const geminiModel = String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'gemini-2.5-flash',
    );

    const cfToken =
        String.fromEnvironment('CF_API_TOKEN');
    const cfAccountId =
        String.fromEnvironment('CF_ACCOUNT_ID');
    const cfModel = String.fromEnvironment(
      'CF_MODEL',
      defaultValue: '@cf/openai/gpt-oss-120b',
    );

    const hfKey = String.fromEnvironment('HF_API_KEY');
    const hfModel = String.fromEnvironment(
      'HF_MODEL',
      defaultValue: 'openai/gpt-oss-120b:fastest',
    );

    if (geminiKey.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          'AIService: using Gemini provider '
          '(model: $geminiModel).',
        );
      }
      return AIService._(
        GeminiProvider(apiKey: geminiKey, model: geminiModel),
      );
    }

    if (cfToken.trim().isNotEmpty &&
        cfAccountId.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          'AIService: using Cloudflare provider '
          '(model: $cfModel).',
        );
      }
      return AIService._(
        CloudflareProvider(
          apiToken: cfToken,
          accountId: cfAccountId,
          model: cfModel,
        ),
      );
    }

    if (hfKey.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          'AIService: using Hugging Face provider '
          '(model: $hfModel).',
        );
      }
      return AIService._(
        HuggingFaceProvider(apiKey: hfKey, model: hfModel),
      );
    }

    if (kDebugMode) {
      debugPrint(
        'AIService: no API key found in --dart-define. '
        'App will throw a clear error on first send.',
      );
    }
    return AIService._(
      HuggingFaceProvider(apiKey: '', model: hfModel),
    );
  }

  // ============================================================
  // PUBLIC API — same signature as before
  // ============================================================

  Future<String> sendMessage({
    required String message,
    List<AIChatMessage> history = const [],
    String? systemPrompt,
    Character? character,
    String? extraSystemContext,
  }) {
    return _provider.sendMessage(
      message: message,
      history: history,
      systemPrompt: systemPrompt,
      character: character,
      extraSystemContext: extraSystemContext,
    );
  }
}