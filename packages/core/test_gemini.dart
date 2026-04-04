// ignore_for_file: avoid_print
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  print('Iniciando Test Local Generative AI...');
  try {
    const apiKey = 'AIzaSyDxCMDUQMKg4Y3GcUV872rG85NvgUS0xS8';

    // Probar el modelo permitido 'gemini-flash-latest'
    final modelName = 'gemini-flash-latest';
    print('Testing model: $modelName');
    final model = GenerativeModel(model: modelName, apiKey: apiKey);

    final content = [
      Content.text('Hola, responde solo con la palabra: FUNCIONA')
    ];

    print('Enviando request...');
    final response = await model.generateContent(content);
    print('Respuesta: ${response.text}');
  } catch (e) {
    print('ERROR ENCONTRADO: $e');
  }
}
