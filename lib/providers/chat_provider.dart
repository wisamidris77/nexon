import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/ai_provider.dart';
import 'package:nexon/models/message.dart';
import 'package:nexon/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Key for storing settings in SharedPreferences
const String SETTINGS_STORAGE_KEY = 'nexon_ai_settings';

final chatMessagesProvider = StateNotifierProvider<ChatNotifier, List<Message>>((ref) {
  final settingsNotifier = ref.watch(aiSettingsProvider.notifier);
  return ChatNotifier(settingsNotifier);
});

final isGeneratingProvider = StateProvider<bool>((ref) => false);

final aiSettingsProvider = StateNotifierProvider<AISettingsNotifier, AISettings>((ref) {
  return AISettingsNotifier();
});

class AISettingsNotifier extends StateNotifier<AISettings> {
  AISettingsNotifier() : super(AISettings(apiKey: '', selectedModel: AIModels.getDefaultModel())) {
    // Load saved settings when initialized
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSettings = prefs.getString(SETTINGS_STORAGE_KEY);

      if (savedSettings != null) {
        final Map<String, dynamic> settingsMap = jsonDecode(savedSettings);
        state = AISettings.fromJson(settingsMap);
      }
    } catch (e) {
      // If loading fails, keep the default settings
      print('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(state.toJson());
      await prefs.setString(SETTINGS_STORAGE_KEY, settingsJson);
    } catch (e) {
      print('Failed to save settings: $e');
    }
  }

  void updateApiKey(String apiKey) {
    state = state.copyWith(apiKey: apiKey);
    _saveSettings();
  }

  void updateModel(AIModel model) {
    state = state.copyWith(selectedModel: model);
    _saveSettings();
  }

  void updateTemperature(double temperature) {
    state = state.copyWith(temperature: temperature);
    _saveSettings();
  }

  void updateMaxTokens(int maxTokens) {
    state = state.copyWith(maxTokens: maxTokens);
    _saveSettings();
  }

  void updateTopP(double topP) {
    state = state.copyWith(topP: topP);
    _saveSettings();
  }
}

class ChatNotifier extends StateNotifier<List<Message>> {
  ChatNotifier(this._settingsNotifier) : super([]);

  final AISettingsNotifier _settingsNotifier;
  AIService? _currentService;

  Future<void> sendMessage(String text) async {
    // If text is empty, don't send
    if (text.trim().isEmpty) return;

    // Clean up text by removing extra newlines
    final cleanedText = text.replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Replace 3+ newlines with 2

    // Check if we're editing a message
    final editingIndex = state.indexWhere((m) => m.isEditing);
    if (editingIndex != -1) {
      // Update the message content
      final updatedMessage = state[editingIndex].copyWith(blocks: [TextBlock(text: cleanedText)], isEditing: false);

      // Replace the message in state
      state = [...state.sublist(0, editingIndex), updatedMessage, ...state.sublist(editingIndex + 1, state.length)];

      // Remove any bot responses after this message
      final nextBotIndex = state.indexWhere((m) => m.role == Role.bot && state.indexOf(m) > editingIndex);

      if (nextBotIndex != -1) {
        state = state.sublist(0, nextBotIndex);
      }

      // Generate a new response
      await _generateResponse();
      return;
    }

    // Create a new user message
    final userMessage = Message(role: Role.user, blocks: [TextBlock(text: cleanedText)]);

    // Add to the state
    state = [...state, userMessage];

    // Generate a response from the AI
    await _generateResponse();
  }

  Future<void> _generateResponse() async {
    try {
      // Set generating state to true
      final container = ProviderContainer();
      container.read(isGeneratingProvider.notifier).state = true;

      // Create or get the AI service
      final settings = _settingsNotifier.state;
      _currentService = AIService.create(settings.selectedModel.provider);

      // Generate a response
      final responseStream = await _currentService!.generateStreamResponse(state, settings);

      // Create a pending bot message
      String responseText = '';
      final botMessageId = const Uuid().v4();

      // Stream the response
      await for (final chunk in responseStream) {
        responseText += chunk;

        // Update the bot message with the latest text
        _updateBotMessage(botMessageId, responseText);
      }
    } catch (e) {
      // Handle errors
      final errorMessage = Message(role: Role.bot, blocks: [TextBlock(text: 'Error: ${e.toString()}')]);
      state = [...state, errorMessage];
    } finally {
      // Set generating state to false
      final container = ProviderContainer();
      container.read(isGeneratingProvider.notifier).state = false;
    }
  }

  void _updateBotMessage(String botMessageId, String text) {
    // Clean up the text - this is especially important for streaming updates
    final cleanedText = text.replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Replace 3+ newlines with 2

    // Check if the bot message already exists
    final botIndex = state.indexWhere((m) => m.id == botMessageId);
    final botMessage = Message(id: botMessageId, role: Role.bot, blocks: [TextBlock(text: cleanedText)]);

    if (botIndex == -1) {
      // If not found, add it
      state = [...state, botMessage];
    } else {
      // If found, update it
      state = [...state.sublist(0, botIndex), botMessage, ...state.sublist(botIndex + 1)];
    }
  }

  Future<void> stopGeneration() async {
    if (_currentService != null) {
      await _currentService!.stopGeneration();
      final container = ProviderContainer();
      container.read(isGeneratingProvider.notifier).state = false;
    }
  }

  void startEditingMessage(String messageId) {
    // Set all messages to not editing
    state =
        state.map((message) {
          return message.id == messageId ? message.copyWith(isEditing: true) : message.copyWith(isEditing: false);
        }).toList();
  }

  void cancelEditing() {
    // Set all messages to not editing
    state = state.map((message) => message.copyWith(isEditing: false)).toList();
  }
}
