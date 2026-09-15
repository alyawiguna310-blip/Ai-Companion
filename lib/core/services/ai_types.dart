/// Thrown by any [AIProvider] when a request cannot be completed.
class AIServiceException implements Exception {
  final String message;

  const AIServiceException(this.message);

  @override
  String toString() => message;
}

/// A single chat message in provider-neutral form.
///
/// Providers translate this into whatever shape their API expects.
class AIChatMessage {
  final String role;
  final String content;

  const AIChatMessage({
    required this.role,
    required this.content,
  });

  const AIChatMessage.system(this.content) : role = 'system';

  const AIChatMessage.user(this.content) : role = 'user';

  const AIChatMessage.assistant(this.content) : role = 'assistant';
}