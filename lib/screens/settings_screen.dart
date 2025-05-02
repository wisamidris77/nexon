import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/ai_provider.dart';
import 'package:nexon/providers/chat_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _customModelIdController = TextEditingController();
  bool _isApiKeyVisible = false;
  AIProvider _selectedProvider = AIProvider.gemini;
  AIModel? _selectedModel;
  bool _useCustomModel = false;
  double _temperature = 0.7;
  int _maxTokens = 1024;
  double _topP = 0.95;

  @override
  void initState() {
    super.initState();
    // Initialize values from the provider state
    final settings = ref.read(aiSettingsProvider);
    _apiKeyController.text = settings.apiKey;
    _selectedProvider = settings.selectedModel.provider;
    _selectedModel = settings.selectedModel;
    _temperature = settings.temperature;
    _maxTokens = settings.maxTokens;
    _topP = settings.topP;

    // Check if current model is custom
    _useCustomModel = !AIModels.getAllModels().any((model) => model.provider == _selectedModel?.provider && model.id == _selectedModel?.id);

    if (_useCustomModel && _selectedModel != null) {
      _customModelIdController.text = _selectedModel!.id;
    }

    // Add listener to save as user types
    _apiKeyController.addListener(_saveApiKey);
    _customModelIdController.addListener(_saveCustomModel);
  }

  @override
  void dispose() {
    _apiKeyController.removeListener(_saveApiKey);
    _customModelIdController.removeListener(_saveCustomModel);
    _apiKeyController.dispose();
    _customModelIdController.dispose();
    super.dispose();
  }

  void _saveApiKey() {
    final settingsNotifier = ref.read(aiSettingsProvider.notifier);
    settingsNotifier.updateApiKey(_apiKeyController.text);
  }

  void _saveCustomModel() {
    if (_useCustomModel && _customModelIdController.text.isNotEmpty) {
      final settingsNotifier = ref.read(aiSettingsProvider.notifier);
      AIModel model = AIModel(
        provider: _selectedProvider,
        id: _customModelIdController.text,
        name: 'Custom Model',
        description: 'Custom model configuration',
      );
      settingsNotifier.updateModel(model);
    }
  }

  void _updateModel(AIModel? model) {
    if (model != null) {
      setState(() {
        _selectedModel = model;
      });
      final settingsNotifier = ref.read(aiSettingsProvider.notifier);
      settingsNotifier.updateModel(model);
    }
  }

  void _updateProvider(AIProvider? provider) {
    if (provider != null) {
      setState(() {
        _selectedProvider = provider;
        _selectedModel = null;
        _useCustomModel = false;
      });

      // Set default model for this provider
      if (provider == AIProvider.gemini) {
        _updateModel(AIModels.geminiModels.first);
      } else if (provider == AIProvider.openai) {
        _updateModel(AIModels.openaiModels.first);
      }
    }
  }

  void _updateTemperature(double value) {
    setState(() {
      _temperature = value;
    });
    ref.read(aiSettingsProvider.notifier).updateTemperature(value);
  }

  void _updateMaxTokens(double value) {
    final tokens = value.toInt();
    setState(() {
      _maxTokens = tokens;
    });
    ref.read(aiSettingsProvider.notifier).updateMaxTokens(tokens);
  }

  void _updateTopP(double value) {
    setState(() {
      _topP = value;
    });
    ref.read(aiSettingsProvider.notifier).updateTopP(value);
  }

  void _updateUseCustomModel(bool? value) {
    if (value != null) {
      setState(() {
        _useCustomModel = value;
      });

      if (!value && _selectedModel == null) {
        // If turning off custom model, select a default model
        if (_selectedProvider == AIProvider.gemini) {
          _updateModel(AIModels.geminiModels.first);
        } else if (_selectedProvider == AIProvider.openai) {
          _updateModel(AIModels.openaiModels.first);
        }
      } else if (value && _customModelIdController.text.isNotEmpty) {
        _saveCustomModel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get available models for the selected provider
    List<AIModel> availableModels = _selectedProvider == AIProvider.gemini ? AIModels.geminiModels : AIModels.openaiModels;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        scrolledUnderElevation: 0,
        actions: [IconButton(icon: const Icon(Icons.check_circle_outline_rounded), tooltip: 'Settings are auto-saved', onPressed: null)],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: colorScheme.background,
          image: DecorationImage(
            image: const AssetImage('assets/settings_background.png'),
            opacity: 0.02,
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(colorScheme.primary.withOpacity(0.1), BlendMode.srcOver),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // API Key Section
            _buildSettingsCard(
              context,
              title: 'API Key',
              icon: Icons.key_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your API key for the selected model provider',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: !_isApiKeyVisible,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'Enter API key here',
                      prefixIcon: Icon(Icons.security_rounded, color: colorScheme.primary.withOpacity(0.7)),
                      suffixIcon: IconButton(
                        icon: Icon(_isApiKeyVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          setState(() {
                            _isApiKeyVisible = !_isApiKeyVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Model Selection Section
            _buildSettingsCard(
              context,
              title: 'Model Settings',
              icon: Icons.smart_toy_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider Selection
                  DropdownButtonFormField<AIProvider>(
                    value: _selectedProvider,
                    decoration: const InputDecoration(labelText: 'AI Provider', hintText: 'Select AI provider'),
                    items:
                        AIProvider.values.map((provider) {
                          String label;
                          IconData icon;
                          switch (provider) {
                            case AIProvider.gemini:
                              label = 'Google Gemini';
                              icon = Icons.smart_toy_rounded;
                              break;
                            case AIProvider.openai:
                              label = 'OpenAI (mock)';
                              icon = Icons.psychology_alt_rounded;
                              break;
                            case AIProvider.custom:
                              label = 'Custom Provider';
                              icon = Icons.settings_rounded;
                              break;
                          }

                          return DropdownMenuItem(
                            value: provider,
                            child: Row(children: [Icon(icon, size: 18, color: colorScheme.primary), const SizedBox(width: 12), Text(label)]),
                          );
                        }).toList(),
                    onChanged: _updateProvider,
                  ),

                  const SizedBox(height: 16),

                  // Custom Model Checkbox with Material 3 style
                  SwitchListTile(
                    title: const Text('Use Custom Model'),
                    subtitle: Text(
                      'Enable to specify a custom model identifier',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    value: _useCustomModel,
                    onChanged: _updateUseCustomModel,
                    activeColor: colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 8),

                  // Model Selection or Custom Model Input
                  AnimatedCrossFade(
                    firstChild: TextField(
                      controller: _customModelIdController,
                      decoration: const InputDecoration(
                        labelText: 'Custom Model ID',
                        hintText: 'e.g., gemini-ultra',
                        helperText: 'Enter the model identifier for your custom model',
                      ),
                    ),
                    secondChild: DropdownButtonFormField<AIModel>(
                      value: _findExactModelMatch(availableModels),
                      decoration: const InputDecoration(labelText: 'Model', hintText: 'Select model'),
                      items:
                          availableModels.map((model) {
                            return DropdownMenuItem(
                              value: model,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(model.name, style: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                                  if (model.description != null)
                                    Text(model.description!, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6))),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: _updateModel,
                    ),
                    crossFadeState: _useCustomModel ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),

            // Advanced Settings Section
            _buildSettingsCard(
              context,
              title: 'Advanced Settings',
              icon: Icons.tune_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Temperature Slider
                  _buildSliderSetting(
                    context,
                    title: 'Temperature',
                    value: _temperature,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    valueLabel: _temperature.toStringAsFixed(2),
                    description: 'Lower values make responses more focused and deterministic',
                    icon: Icons.thermostat_rounded,
                    onChanged: _updateTemperature,
                  ),

                  const Divider(height: 32),

                  // Max Tokens Slider
                  _buildSliderSetting(
                    context,
                    title: 'Max Tokens',
                    value: _maxTokens.toDouble(),
                    min: 100,
                    max: 8192,
                    divisions: 80,
                    valueLabel: _maxTokens.toString(),
                    description: 'Maximum length of the generated response',
                    icon: Icons.text_fields_rounded,
                    onChanged: _updateMaxTokens,
                  ),

                  const Divider(height: 32),

                  // Top P Slider
                  _buildSliderSetting(
                    context,
                    title: 'Top P',
                    value: _topP,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    valueLabel: _topP.toStringAsFixed(2),
                    description: 'Controls diversity of the generated response',
                    icon: Icons.bubble_chart_rounded,
                    onChanged: _updateTopP,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
              ],
            ),
            const Divider(height: 32),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required String description,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(valueLabel, style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.primary, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(value: value, min: min, max: max, divisions: divisions, label: valueLabel, onChanged: onChanged),
        Text(description, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6))),
      ],
    );
  }

  AIModel? _findExactModelMatch(List<AIModel> models) {
    for (var model in models) {
      if (model.provider == _selectedProvider && model.id == _selectedModel?.id) {
        return model;
      }
    }
    return null;
  }
}
