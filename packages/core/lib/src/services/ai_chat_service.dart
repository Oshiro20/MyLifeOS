import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_service.dart';
import 'offline_cache_service.dart';
import 'connectivity_service.dart';

// ── Modelo de mensaje ─────────────────────────────────────────────────────────

/// Representa un mensaje en la conversación con el asistente IA de MyLifeOS.
class AiChatMessage {
  final String id;
  final bool isUser; // true = usuario, false = IA
  final String content;
  final DateTime timestamp;
  final bool isLoading; // true mientras la IA está respondiendo

  const AiChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
  });

  AiChatMessage copyWith({String? content, bool? isLoading}) => AiChatMessage(
        id: id,
        isUser: isUser,
        content: content ?? this.content,
        timestamp: timestamp,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Prompt del sistema ────────────────────────────────────────────────────────

const _kSystemPrompt = '''
Eres el asistente personal de MyLifeOS, el sistema operativo personal de Joel.
MyLifeOS integra 4 módulos principales:
- 👗 Armario: gestión de prendas y outfits con sugerencias de IA
- 🍽️ Cocina: recetas, despensa y planificación de comidas
- 💰 Finanzas (WalletAI): control de gastos e ingresos mensuales
- 🥗 FoodCoach: seguimiento nutricional y evaluación de comidas con IA

Tu rol:
- Responde siempre en español, de forma concisa, amigable y directa.
- Si el usuario pregunta sobre un módulo específico, guíalo hacia él.
- Puedes dar consejos de moda, nutrición, ahorro o cocina según el contexto.
- Nunca inventes datos financieros o de salud del usuario; usa solo el contexto provisto.
- Si no tienes contexto suficiente, pide más información al usuario.
''';

// ── Notifier (Riverpod 3 — Notifier<T>) ──────────────────────────────────────

/// Gestiona el historial del chat conversacional con Gemini AI.
class AiChatNotifier extends Notifier<List<AiChatMessage>> {
  @override
  List<AiChatMessage> build() => [];

  GeminiService get _gemini => ref.read(geminiProvider);
  OfflineCacheService get _cache => ref.read(offlineCacheProvider);
  ConnectivityService get _conn => ref.read(connectivityProvider);

  /// Envía un mensaje del usuario y obtiene la respuesta de Gemini.
  ///
  /// [walletContext] — texto opcional con balance/gastos del mes.
  /// [outfitContext] — texto opcional con outfit del día.
  Future<void> sendMessage(
    String text, {
    String? walletContext,
    String? outfitContext,
  }) async {
    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: true,
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    final loadingId = '${userMsg.id}_ai';
    final loadingMsg = AiChatMessage(
      id: loadingId,
      isUser: false,
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = [...state, userMsg, loadingMsg];

    String aiResponse;
    try {
      final online = await _conn.isOnline();
      if (!online) {
        aiResponse = '📡 Sin conexión. Por favor revisa tu red e inténtalo de nuevo.';
      } else {
        final raw = await _callGemini(
          text,
          walletContext: walletContext,
          outfitContext: outfitContext,
        );
        aiResponse = raw ?? 'No pude procesar tu mensaje. ¿Podrías intentarlo de nuevo?';
        await _cache.saveString(
          'chat_last',
          '{"q":${_esc(text)},"a":${_esc(aiResponse)}}',
        );
      }
    } catch (e) {
      debugPrint('[AiChat] Error: $e');
      aiResponse = '⚠️ Error al conectar con el asistente. Inténtalo de nuevo.';
    }

    state = state
        .map((m) => m.id == loadingId
            ? m.copyWith(content: aiResponse, isLoading: false)
            : m)
        .toList();
  }

  /// Limpia todo el historial del chat.
  void clearHistory() => state = [];

  // ── Lógica de Gemini ────────────────────────────────────────────────────────

  Future<String?> _callGemini(
    String userMessage, {
    String? walletContext,
    String? outfitContext,
  }) async {
    final apiKey = _gemini.apiKey;
    if (apiKey.isEmpty) return null;

    final systemText = _systemWithContext(
      walletContext: walletContext,
      outfitContext: outfitContext,
    );

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(systemText),
    );

    // Construye historial multi-turno (excluye el loading actual)
    final history = state
        .where((m) => !m.isLoading && m.content.isNotEmpty)
        .take(state.length - 1)
        .map((m) => m.isUser
            ? Content.text(m.content)
            : Content.model([TextPart(m.content)]))
        .toList();

    final chat = model.startChat(history: history);
    final result = await chat.sendMessage(Content.text(userMessage));
    return result.text;
  }

  String _systemWithContext({String? walletContext, String? outfitContext}) {
    final sb = StringBuffer(_kSystemPrompt);
    if (walletContext != null) sb.writeln('\nContexto financiero: $walletContext');
    if (outfitContext != null) sb.writeln('Outfit del día: $outfitContext');
    return sb.toString();
  }

  String _esc(String t) => '"${t.replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
}

// ── Providers ─────────────────────────────────────────────────────────────────

final aiChatProvider =
    NotifierProvider<AiChatNotifier, List<AiChatMessage>>(AiChatNotifier.new);
