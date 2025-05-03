import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/ai_provider.dart';
import 'package:nexon/providers/chat_provider.dart';
import 'package:nexon/models/folder.dart';
import 'package:nexon/models/tag.dart';
import 'package:nexon/providers/conversation_provider.dart';
import 'package:nexon/providers/database_provider.dart';
import 'package:nexon/providers/theme_provider.dart';
import 'package:nexon/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  final _apiKeyController = TextEditingController();
  final _customModelIdController = TextEditingController();
  bool _isApiKeyVisible = false;
  AIProvider _selectedProvider = AIProvider.gemini;
  AIModel? _selectedModel;
  bool _useCustomModel = false;
  double _temperature = 0.7;
  int _maxTokens = 1024;
  double _topP = 0.95;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
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
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'General'), Tab(text: 'Folders'), Tab(text: 'Tags')]),
      ),
      body: TabBarView(controller: _tabController, children: const [GeneralSettingsTab(), FoldersSettingsTab(), TagsSettingsTab()]),
    );
  }
}

class GeneralSettingsTab extends ConsumerStatefulWidget {
  const GeneralSettingsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends ConsumerState<GeneralSettingsTab> {
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

    // Debug mode
    final debugMode = ref.watch(settingsProvider.select((s) => s.debugMode));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: 'Appearance'),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Use dark theme'),
          value: Theme.of(context).brightness == Brightness.dark,
          onChanged: (value) {
            ref.read(themeProvider.notifier).toggleTheme();
          },
        ),

        // Debug Mode
        SwitchListTile(
          title: const Text('Debug Mode'),
          subtitle: const Text('Show additional debugging information'),
          value: debugMode,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).toggleDebugMode();
          },
        ),

        const Divider(),

        const SectionHeader(title: 'AI Model Settings'),

        // Provider selection
        DropdownButtonFormField<AIProvider>(
          decoration: const InputDecoration(labelText: 'AI Provider'),
          value: _selectedProvider,
          items:
              AIProvider.values.map((provider) {
                return DropdownMenuItem(value: provider, child: Text(provider.toString().split('.').last));
              }).toList(),
          onChanged: _updateProvider,
        ),

        const SizedBox(height: 16),

        // API Key
        TextFormField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            labelText: 'API Key',
            suffixIcon: IconButton(
              icon: Icon(_isApiKeyVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() {
                  _isApiKeyVisible = !_isApiKeyVisible;
                });
              },
            ),
          ),
          obscureText: !_isApiKeyVisible,
        ),

        const SizedBox(height: 16),

        // Model selection
        if (!_useCustomModel) ...[
          DropdownButtonFormField<AIModel>(
            decoration: const InputDecoration(labelText: 'Model'),
            value: _selectedModel,
            items:
                availableModels.map((model) {
                  return DropdownMenuItem(value: model, child: Text(model.name));
                }).toList(),
            onChanged: _updateModel,
          ),
        ],

        // Custom model checkbox
        CheckboxListTile(title: const Text('Use custom model'), value: _useCustomModel, onChanged: _updateUseCustomModel),

        // Custom model ID field
        if (_useCustomModel) ...[
          TextFormField(
            controller: _customModelIdController,
            decoration: const InputDecoration(labelText: 'Custom Model ID', hintText: 'Enter the model ID (e.g., gpt-4o)'),
          ),
        ],

        const Divider(),
        const SectionHeader(title: 'Generation Parameters'),

        // Temperature slider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Temperature: ${_temperature.toStringAsFixed(2)}'),
              Slider(value: _temperature, min: 0.0, max: 1.0, divisions: 20, onChanged: _updateTemperature),
              const Text(
                'Lower values make responses more focused and deterministic. Higher values make responses more creative and varied.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Top-p (nucleus sampling) slider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Top-P: ${_topP.toStringAsFixed(2)}'),
              Slider(value: _topP, min: 0.0, max: 1.0, divisions: 20, onChanged: _updateTopP),
              const Text(
                'Controls diversity by limiting tokens to a cumulative probability. Lower values make responses more deterministic.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Max tokens slider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Max Tokens: $_maxTokens'),
              Slider(value: _maxTokens.toDouble(), min: 256, max: 8192, divisions: 31, onChanged: _updateMaxTokens),
              const Text(
                'Maximum number of tokens to generate in the response. A token is about 4 characters.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FoldersSettingsTab extends ConsumerWidget {
  const FoldersSettingsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);

    return foldersAsync.when(
      data: (folders) => _buildFoldersList(context, ref, folders),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Error loading folders: $error')),
    );
  }

  Widget _buildFoldersList(BuildContext context, WidgetRef ref, List<Folder> folders) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: folders.length,
        itemBuilder: (context, index) {
          final folder = folders[index];
          return ListTile(
            leading: Icon(Icons.folder, color: Color(int.parse(folder.colorHex.substring(1, 7), radix: 16) + 0xFF000000)),
            title: Text(folder.name),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showFolderEditDialog(context, ref, folder);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showFolderEditDialog(context, ref, null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFolderEditDialog(BuildContext context, WidgetRef ref, Folder? folder) {
    final isEditing = folder != null;
    final nameController = TextEditingController(text: folder?.name ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isEditing ? 'Edit Folder' : 'New Folder'),
            content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Folder Name'), autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    final repository = ref.read(conversationRepositoryProvider);

                    if (isEditing) {
                      // Update existing folder
                      repository.updateFolder(folder!.copyWith(name: name));
                    } else {
                      // Create new folder
                      repository.createFolder(Folder(name: name));
                    }

                    ref.invalidate(foldersProvider);
                    Navigator.of(context).pop();
                  }
                },
                child: Text(isEditing ? 'UPDATE' : 'CREATE'),
              ),
            ],
          ),
    );
  }
}

class TagsSettingsTab extends ConsumerWidget {
  const TagsSettingsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return tagsAsync.when(
      data: (tags) => _buildTagsList(context, ref, tags),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Error loading tags: $error')),
    );
  }

  Widget _buildTagsList(BuildContext context, WidgetRef ref, List<Tag> tags) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
          return ListTile(
            leading: Icon(Icons.label, color: Color(int.parse(tag.colorHex.substring(1, 7), radix: 16) + 0xFF000000)),
            title: Text(tag.name),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showTagEditDialog(context, ref, tag);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showTagEditDialog(context, ref, null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTagEditDialog(BuildContext context, WidgetRef ref, Tag? tag) {
    final isEditing = tag != null;
    final nameController = TextEditingController(text: tag?.name ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isEditing ? 'Edit Tag' : 'New Tag'),
            content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tag Name'), autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    final repository = ref.read(conversationRepositoryProvider);

                    if (isEditing) {
                      // Update existing tag
                      repository.updateTag(tag!.copyWith(name: name));
                    } else {
                      // Create new tag
                      repository.createTag(Tag(name: name));
                    }

                    ref.invalidate(tagsProvider);
                    Navigator.of(context).pop();
                  }
                },
                child: Text(isEditing ? 'UPDATE' : 'CREATE'),
              ),
            ],
          ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
