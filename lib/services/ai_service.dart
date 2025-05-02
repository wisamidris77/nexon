import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nexon/models/ai_provider.dart';
import 'package:nexon/models/message.dart';
import 'package:async/async.dart';

abstract class AIService {
  Future<Stream<String>> generateStreamResponse(List<Message> messages, AISettings settings);
  Future<void> stopGeneration();

  factory AIService.create(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return GeminiService();
      case AIProvider.openai:
        return OpenAIMockService();
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

class OpenAIMockService implements AIService {
  Timer? _mockStreamTimer;

  @override
  Future<Stream<String>> generateStreamResponse(List<Message> messages, AISettings settings) async {
    final completer = Completer<Stream<String>>();

    final lastMessage = messages.last;
    String userQuery = "";

    for (final block in lastMessage.blocks) {
      if (block is TextBlock) {
        userQuery += block.text;
      }
    }

    final mockResponse = "This is a mock response from OpenAI for your query: $userQuery";

    final controller = StreamController<String>();

    int chunkSize = 10;
    int position = 0;

    _mockStreamTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (position < mockResponse.length) {
        int end = (position + chunkSize) < mockResponse.length ? position + chunkSize : mockResponse.length;
        controller.add(mockResponse.substring(position, end));
        position = end;
      } else {
        timer.cancel();
        controller.close();
      }
    });

    completer.complete(controller.stream);
    return completer.future;
  }

  @override
  Future<void> stopGeneration() async {
    if (_mockStreamTimer != null && _mockStreamTimer!.isActive) {
      _mockStreamTimer!.cancel();
    }
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
