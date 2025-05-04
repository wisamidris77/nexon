import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nexon/models/ai_provider.dart';
import 'package:nexon/models/message.dart';
import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

abstract class AIService {
  Future<Stream<String>> generateStreamResponse(List<Message> messages, AISettings settings);
  Future<void> stopGeneration();

  factory AIService.create(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return GeminiService();
      case AIProvider.openai:
        return OpenAIService();
      case AIProvider.custom:
        return CustomAIService();
    }
  }
}

class GeminiService implements AIService {
  GenerativeModel? _model;
  CancelableCompleter<void>? _currentOperation;

  @override
  Future<Stream<String>> generateStreamResponse(List<Message> messages, AISettings settings) async {
    final apiKey = settings.apiKey;
    if (apiKey.isEmpty) {
      throw Exception('API key is required for Gemini');
    }

    _model = GenerativeModel(
      model: settings.selectedModel.id,
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: settings.temperature, maxOutputTokens: settings.maxTokens, topP: settings.topP),
    );

    final history = _convertMessagesToContent(messages.sublist(0, messages.length - 1));
    final lastMessage = _convertMessageToContent(messages.last);

    try {
      final chat = _model!.startChat(history: history);

      final responseStream = chat.sendMessageStream(lastMessage);

      final controller = StreamController<String>();

      _currentOperation = CancelableCompleter<void>();

      _currentOperation!.operation = Future(() async {
        try {
          await for (final response in responseStream) {
            final text = response.text;
            if (text != null) {
              controller.add(text);
            }
          }
          controller.close();
        } catch (e) {
          controller.addError(e);
          controller.close();
        }
      });

      _currentOperation!.operation.catchError((e) {
        controller.addError(e);
        controller.close();
      });

      return controller.stream;
    } catch (e) {
      throw Exception('Failed to generate response: $e');
    }
  }

  @override
  Future<void> stopGeneration() async {
    if (_currentOperation != null && !_currentOperation!.isCompleted) {
      _currentOperation!.operation.ignore();
      _currentOperation!.completeError(Exception('Operation canceled by user'));
    }
  }

  List<Content> _convertMessagesToContent(List<Message> messages) {
    return messages.map(_convertMessageToContent).toList();
  }

  Content _convertMessageToContent(Message message) {
    String text = "";

    for (final block in message.blocks) {
      if (block is TextBlock) {
        text += block.text;
      }
    }

    return Content.text(text);
  }
}

class OpenAIService implements AIService {
  CancelableCompleter<void>? _currentOperation;
  http.Client? _client;

  @override
  Future<Stream<String>> generateStreamResponse(List<Message> messages, AISettings settings) async {
    final apiKey = settings.apiKey;
    if (apiKey.isEmpty) {
      throw Exception('API key is required for OpenAI');
    }

    final controller = StreamController<String>();
    _client = http.Client();
    _currentOperation = CancelableCompleter<void>();

    try {
      final openAIMessages = _convertMessagesToOpenAIFormat(messages);

      final requestBody = jsonEncode({
        'model': settings.selectedModel.id,
        'messages': openAIMessages,
        'temperature': settings.temperature,
        'max_tokens': settings.maxTokens,
        'top_p': settings.topP,
        'stream': true,
      });

      final request = http.Request('POST', Uri.parse('https://api.openai.com/v1/chat/completions'));
      request.headers.addAll({'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'});
      request.body = requestBody;

      _currentOperation!.operation = Future(() async {
        try {
          final response = await _client!.send(request);

          if (response.statusCode != 200) {
            final errorBody = await response.stream.bytesToString();
            throw Exception('OpenAI API error: ${response.statusCode} - $errorBody');
          }

          await for (final chunk in response.stream.transform(utf8.decoder)) {
            if (_currentOperation!.isCompleted) break;

            // Process SSE format
            final lines = chunk.split('\n').where((line) => line.trim().isNotEmpty);

            for (final line in lines) {
              if (line.startsWith('data: ')) {
                final data = line.substring(6);
                if (data == '[DONE]') {
                  break;
                }

                try {
                  final jsonData = jsonDecode(data);
                  final choices = jsonData['choices'] as List;
                  if (choices.isNotEmpty) {
                    final delta = choices[0]['delta'];
                    final content = delta['content'];
                    if (content != null) {
                      controller.add(content);
                    }
                  }
                } catch (e) {
                  // Skip invalid JSON
                }
              }
            }
          }

          controller.close();
        } catch (e) {
          controller.addError(e);
          controller.close();
        } finally {
          _client?.close();
        }
      });

      return controller.stream;
    } catch (e) {
      controller.addError(e);
      controller.close();
      return controller.stream;
    }
  }

  @override
  Future<void> stopGeneration() async {
    if (_currentOperation != null && !_currentOperation!.isCompleted) {
      _currentOperation!.operation.ignore();
      _currentOperation!.completeError(Exception('Operation canceled by user'));
      _client?.close();
    }
  }

  List<Map<String, String>> _convertMessagesToOpenAIFormat(List<Message> messages) {
    return messages.map((message) {
      String content = "";

      for (final block in message.blocks) {
        if (block is TextBlock) {
          content += block.text;
        }
      }

      return {'role': message.role == Role.user ? 'user' : 'assistant', 'content': content};
    }).toList();
  }
}

class CustomAIService implements AIService {
  @override
  Future<Stream<String>> generateStreamResponse(List<Message> messages, AISettings settings) async {
    final controller = StreamController<String>();
    controller.add("Custom AI service is not implemented yet");
    controller.close();
    return controller.stream;
  }

  @override
  Future<void> stopGeneration() async {
    // Implement cancellation for custom service
  }
}

class CancelableCompleter<T> {
  late Future<T> operation;
  final _completer = Completer<T>();

  Future<T> get future => _completer.future;
  bool get isCompleted => _completer.isCompleted;

  void complete(T value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}
