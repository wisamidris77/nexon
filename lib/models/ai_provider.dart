enum AIProvider { gemini, openai, custom }

class AIModel {
  final AIProvider provider;
  final String id;
  final String name;
  final String? description;

  AIModel({required this.provider, required this.id, required this.name, this.description});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIModel && other.provider == provider && other.id == id;
  }

  @override
  int get hashCode => provider.hashCode ^ id.hashCode;

  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      provider: AIProvider.values.firstWhere((provider) => provider.toString().split('.').last == json['provider'], orElse: () => AIProvider.gemini),
      id: json['id'],
      name: json['name'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'provider': provider.toString().split('.').last, 'id': id, 'name': name, 'description': description};
  }
}

class AISettings {
  final String apiKey;
  final AIModel selectedModel;
  final double temperature;
  final int maxTokens;
  final double topP;

  AISettings({required this.apiKey, required this.selectedModel, this.temperature = 0.7, this.maxTokens = 1024, this.topP = 0.95});

  AISettings copyWith({String? apiKey, AIModel? selectedModel, double? temperature, int? maxTokens, double? topP}) {
    return AISettings(
      apiKey: apiKey ?? this.apiKey,
      selectedModel: selectedModel ?? this.selectedModel,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      topP: topP ?? this.topP,
    );
  }

  Map<String, dynamic> toJson() {
    return {'apiKey': apiKey, 'selectedModel': selectedModel.toJson(), 'temperature': temperature, 'maxTokens': maxTokens, 'topP': topP};
  }

  factory AISettings.fromJson(Map<String, dynamic> json) {
    return AISettings(
      apiKey: json['apiKey'],
      selectedModel: AIModel.fromJson(json['selectedModel']),
      temperature: json['temperature'],
      maxTokens: json['maxTokens'],
      topP: json['topP'],
    );
  }
}

// Some predefined models for different providers
class AIModels {
  static final List<AIModel> geminiModels = [
    AIModel(
      provider: AIProvider.gemini,
      id: 'gemini-2.0-flash',
      name: 'Gemini 2.0 Flash',
      description: 'Latest stable flash model for fast responses',
    ),
    AIModel(provider: AIProvider.gemini, id: 'gemini-2.0-flash-001', name: 'Gemini 2.0 Flash 001', description: 'Stable release of the flash model'),
    AIModel(
      provider: AIProvider.gemini,
      id: 'gemini-2.0-flash-exp',
      name: 'Gemini 2.0 Flash (Experimental)',
      description: 'Experimental version with latest capabilities',
    ),
    AIModel(
      provider: AIProvider.gemini,
      id: 'gemini-2.0-flash-thinking-exp-01-21',
      name: 'Gemini 2.0 Flash Thinking',
      description: 'Experimental thinking variant for more nuanced responses',
    ),
    AIModel(
      provider: AIProvider.gemini,
      id: 'gemini-2.0-flash-lite',
      name: 'Gemini 2.0 Flash Lite',
      description: 'Latest stable lite model (less resource intensive)',
    ),
    AIModel(
      provider: AIProvider.gemini,
      id: 'gemini-2.0-flash-lite-001',
      name: 'Gemini 2.0 Flash Lite 001',
      description: 'Stable release of the flash-lite model',
    ),
    AIModel(
      provider: AIProvider.gemini,
      id: 'gemini-2.0-flash-lite-preview-02-05',
      name: 'Gemini 2.0 Flash Lite Preview',
      description: 'Preview version of the flash-lite model',
    ),
    AIModel(
      provider: AIProvider.gemini,
      id: 'gemini-2.0-pro-exp-02-05',
      name: 'Gemini 2.0 Pro (Experimental)',
      description: 'Experimental pro model with advanced capabilities',
    ),
  ];

  static final List<AIModel> openaiModels = [
    AIModel(provider: AIProvider.openai, id: 'gpt-3.5-turbo', name: 'GPT-3.5 Turbo', description: 'Fast and efficient model for most tasks'),
    AIModel(provider: AIProvider.openai, id: 'gpt-4', name: 'GPT-4', description: 'Most advanced OpenAI model with enhanced capabilities'),
  ];

  static List<AIModel> getAllModels() {
    return [...geminiModels, ...openaiModels];
  }

  static AIModel getDefaultModel() {
    return geminiModels.first;
  }
}
