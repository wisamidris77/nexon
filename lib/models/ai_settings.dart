import 'package:nexon/models/ai_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AIProviderSettings {
  final Map<String, String> apiKeys;
  final double temperature;
  final int maxTokens;
  final double topP;

  const AIProviderSettings({this.apiKeys = const {}, this.temperature = 0.7, this.maxTokens = 1024, this.topP = 0.95});

  AIProviderSettings copyWith({Map<String, String>? apiKeys, double? temperature, int? maxTokens, double? topP}) {
    return AIProviderSettings(
      apiKeys: apiKeys ?? this.apiKeys,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      topP: topP ?? this.topP,
    );
  }
}

class AISettingsNotifier extends StateNotifier<AIProviderSettings> {
  AISettingsNotifier() : super(const AIProviderSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load API keys
    final geminiKey = prefs.getString('apiKey_gemini') ?? '';
    final openaiKey = prefs.getString('apiKey_openai') ?? '';
    final customKey = prefs.getString('apiKey_custom') ?? '';

    // Load model settings
    final temperature = prefs.getDouble('ai_temperature') ?? 0.7;
    final maxTokens = prefs.getInt('ai_maxTokens') ?? 1024;
    final topP = prefs.getDouble('ai_topP') ?? 0.95;

    state = AIProviderSettings(
      apiKeys: {'gemini': geminiKey, 'openai': openaiKey, 'custom': customKey},
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
    );
  }

  Future<void> setApiKey(AIProvider provider, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final providerKey = provider.toString().split('.').last;

    await prefs.setString('apiKey_$providerKey', apiKey);

    final updatedKeys = Map<String, String>.from(state.apiKeys);
    updatedKeys[providerKey] = apiKey;

    state = state.copyWith(apiKeys: updatedKeys);
  }

  Future<void> setTemperature(double temperature) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ai_temperature', temperature);
    state = state.copyWith(temperature: temperature);
  }

  Future<void> setMaxTokens(int maxTokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ai_maxTokens', maxTokens);
    state = state.copyWith(maxTokens: maxTokens);
  }

  Future<void> setTopP(double topP) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ai_topP', topP);
    state = state.copyWith(topP: topP);
  }
}

final aiSettingsProvider = StateNotifierProvider<AISettingsNotifier, AIProviderSettings>((ref) {
  return AISettingsNotifier();
});
