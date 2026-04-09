import 'package:flutter/foundation.dart';

/// Servicio para manejo de comandos de voz y transcripción.
/// TEMPORARILY DISABLED - speech_to_text package has Android build incompatibility
class VoiceService {
  bool _isInitialized = false;

  Future<bool> initialize() async {
    debugPrint('[Voice] Service disabled - speech_to_text incompatible');
    _isInitialized = false;
    return false;
  }

  Future<void> startListening({
    required Function(String) onResult,
  }) async {
    debugPrint('[Voice] startListening called but service is disabled');
  }

  Future<void> stopListening() async {
    debugPrint('[Voice] stopListening called but service is disabled');
  }

  bool get isInitialized => _isInitialized;
  bool get isListening => false;
  bool get isAvailable => false;
}
