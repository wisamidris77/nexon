import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/ai_provider.dart';
import 'package:nexon/providers/chat_provider.dart' hide aiSettingsProvider;
import 'package:nexon/models/folder.dart';
import 'package:nexon/models/tag.dart';
import 'package:nexon/providers/conversation_provider.dart';
import 'package:nexon/providers/database_provider.dart';
import 'package:nexon/providers/theme_provider.dart';
import 'package:nexon/providers/settings_provider.dart';
import 'package:nexon/models/ai_settings.dart';

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
    _tabController = TabController(length: 4, vsync: this);
    // Initialize values from the provider state
    final settings = ref.read(aiSettingsProvider);
    // Get the apiKey for the current provider
    _apiKeyController.text = settings.apiKeys[_selectedProvider.toString().split('.').last] ?? '';
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
    settingsNotifier.setApiKey(_selectedProvider, _apiKeyController.text);
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
      // No updateModel method, we'll need to update this later
    }
  }

  void _updateModel(AIModel? model) {
    if (model != null) {
      setState(() {
        _selectedModel = model;
      });
      // No updateModel method in AISettingsNotifier
    }
  }

  void _updateProvider(AIProvider? provider) {
    if (provider != null) {
      setState(() {
        _selectedProvider = provider;
        _selectedModel = null;
        _useCustomModel = false;
      });

      // Update API key field for the selected provider
      final settings = ref.read(aiSettingsProvider);
      _apiKeyController.text = settings.apiKeys[provider.toString().split('.').last] ?? '';

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
    ref.read(aiSettingsProvider.notifier).setTemperature(value);
  }

  void _updateMaxTokens(double value) {
    final tokens = value.toInt();
    setState(() {
      _maxTokens = tokens;
    });
    ref.read(aiSettingsProvider.notifier).setMaxTokens(tokens);
  }

  void _updateTopP(double value) {
    setState(() {
      _topP = value;
    });
    ref.read(aiSettingsProvider.notifier).setTopP(value);
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'General'), Tab(text: 'Appearance'), Tab(text: 'AI Model'), Tab(text: 'Advanced')],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_buildGeneralTab(), _buildAppearanceTab(), _buildAIModelTab(), _buildAdvancedTab()]),
    );
  }

  Widget _buildGeneralTab() {
    final appSettings = ref.watch(settingsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(context, 'Behavior'),
        SwitchListTile(
          title: const Text('Start with new chat'),
          subtitle: const Text('Always open a new chat when starting the app'),
          value: appSettings.startWithNewChat,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('startWithNewChat', value);
          },
        ),
        SwitchListTile(
          title: const Text('Send on Enter'),
          subtitle: const Text('Press Enter to send messages (Shift+Enter for new line)'),
          value: appSettings.sendOnEnter,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('sendOnEnter', value);
          },
        ),
        SwitchListTile(
          title: const Text('Confirm before deleting'),
          subtitle: const Text('Show confirmation dialog before deleting conversations'),
          value: appSettings.confirmDeleteConversation,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('confirmDeleteConversation', value);
          },
        ),

        _buildSectionHeader(context, 'Theme'),
        SwitchListTile(
          title: const Text('Use system theme'),
          subtitle: const Text('Follow your device theme settings'),
          value: appSettings.useSystemTheme,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('useSystemTheme', value);
            if (value) {
              ref.read(themeProvider.notifier).setThemeMode(AppThemeMode.system);
            } else {
              ref.read(themeProvider.notifier).setThemeMode(appSettings.useDarkMode ? AppThemeMode.dark : AppThemeMode.light);
            }
          },
        ),
        if (!appSettings.useSystemTheme)
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Use dark theme'),
            value: appSettings.useDarkMode,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).updateSetting('useDarkMode', value);
              ref.read(themeProvider.notifier).setThemeMode(value ? AppThemeMode.dark : AppThemeMode.light);
            },
          ),
      ],
    );
  }

  Widget _buildAppearanceTab() {
    final appSettings = ref.watch(settingsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(context, 'Message Display'),
        SwitchListTile(
          title: const Text('Show avatars'),
          subtitle: const Text('Display profile avatars in messages'),
          value: appSettings.showAvatars,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('showAvatars', value);
          },
        ),
        SwitchListTile(
          title: const Text('Show timestamps'),
          subtitle: const Text('Display time when messages were sent'),
          value: appSettings.showTimestamps,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('showTimestamps', value);
          },
        ),

        _buildSectionHeader(context, 'Scrolling'),
        SwitchListTile(
          title: const Text('Auto-scroll to bottom'),
          subtitle: const Text('Automatically scroll to newest messages'),
          value: appSettings.autoScrollToBottom,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('autoScrollToBottom', value);
          },
        ),
      ],
    );
  }

  Widget _buildAIModelTab() {
    final settings = ref.watch(aiSettingsProvider);
    List<AIModel> availableModels = _selectedProvider == AIProvider.gemini ? AIModels.geminiModels : AIModels.openaiModels;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(context, 'AI Provider'),

        // Provider selection
        DropdownButtonFormField<AIProvider>(
          decoration: const InputDecoration(labelText: 'AI Provider', border: OutlineInputBorder()),
          value: _selectedProvider,
          items:
              AIProvider.values.map((provider) {
                return DropdownMenuItem(value: provider, child: Text(provider.toString().split('.').last));
              }).toList(),
          onChanged: _updateProvider,
        ),

        const SizedBox(height: 16),

        // Model selection
        if (!_useCustomModel) ...[
          DropdownButtonFormField<AIModel>(
            decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
            value: _selectedModel,
            items:
                availableModels.map((model) {
                  return DropdownMenuItem(value: model, child: Text(model.name));
                }).toList(),
            onChanged: _updateModel,
          ),

          const SizedBox(height: 8),
        ],

        // Custom model checkbox
        CheckboxListTile(title: const Text('Use custom model'), value: _useCustomModel, onChanged: _updateUseCustomModel),

        // Custom model ID input
        if (_useCustomModel) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customModelIdController,
            decoration: const InputDecoration(labelText: 'Custom Model ID', hintText: 'Enter model identifier', border: OutlineInputBorder()),
          ),
        ],

        // API Key
        const SizedBox(height: 16),
        TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            labelText: 'API Key',
            border: const OutlineInputBorder(),
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

        _buildSectionHeader(context, 'Generation Settings'),

        // Temperature slider
        ListTile(title: const Text('Temperature'), subtitle: const Text('Higher values produce more random outputs')),
        Slider(min: 0.0, max: 1.0, divisions: 20, value: _temperature, label: _temperature.toStringAsFixed(2), onChanged: _updateTemperature),

        // Max tokens slider
        ListTile(title: const Text('Max Tokens'), subtitle: const Text('Maximum length of generated text')),
        Slider(min: 256.0, max: 4096.0, divisions: 15, value: _maxTokens.toDouble(), label: _maxTokens.toString(), onChanged: _updateMaxTokens),

        // Top P slider
        ListTile(title: const Text('Top P'), subtitle: const Text('Controls diversity via nucleus sampling')),
        Slider(min: 0.0, max: 1.0, divisions: 20, value: _topP, label: _topP.toStringAsFixed(2), onChanged: _updateTopP),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    final appSettings = ref.watch(settingsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(context, 'Debug'),
        SwitchListTile(
          title: const Text('Debug mode'),
          subtitle: const Text('Show additional debug information'),
          value: appSettings.debugMode,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('debugMode', value);
          },
        ),

        _buildSectionHeader(context, 'Search Settings'),
        SwitchListTile(
          title: const Text('Search in message content'),
          subtitle: const Text('Include message content when searching conversations'),
          value: appSettings.searchInMessages,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('searchInMessages', value);
          },
        ),

        // Show additional options if search in messages is enabled
        if (appSettings.searchInMessages) ...[
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: SwitchListTile(
              title: const Text('Search in user messages'),
              value: appSettings.searchInUserMessages,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).updateSetting('searchInUserMessages', value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: SwitchListTile(
              title: const Text('Search in bot messages'),
              value: appSettings.searchInBotMessages,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).updateSetting('searchInBotMessages', value);
              },
            ),
          ),
        ],

        _buildSectionHeader(context, 'Data Management'),
        // Slider for max conversations in history
        ListTile(title: const Text('Maximum conversations'), subtitle: const Text('Maximum number of chats to keep in history')),
        Slider(
          min: 10,
          max: 200,
          divisions: 19,
          value: appSettings.maxConversationsInHistory.toDouble(),
          label: appSettings.maxConversationsInHistory.toString(),
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSetting('maxConversationsInHistory', value.toInt());
          },
        ),

        // Danger zone for clearing data
        _buildSectionHeader(context, 'Danger Zone', color: Colors.red),
        ListTile(
          title: const Text('Clear all conversations'),
          subtitle: const Text('Delete all chat history (cannot be undone)'),
          trailing: const Icon(Icons.delete_forever, color: Colors.red),
          onTap: () {
            _showClearDataDialog(context);
          },
        ),
      ],
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete All Conversations?'),
            content: const Text('This action cannot be undone. All of your conversations will be permanently deleted.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
              TextButton(
                onPressed: () {
                  // Delete all conversations
                  ref.read(conversationRepositoryProvider).clearAllConversations().then((_) {
                    // Invalidate providers
                    ref.invalidate(conversationsProvider);
                    ref.invalidate(currentConversationProvider);
                    ref.read(currentConversationIdProvider.notifier).state = null;

                    // Close dialog
                    Navigator.of(context).pop();

                    // Show confirmation
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All conversations deleted')));
                  });
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('DELETE ALL'),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? Theme.of(context).colorScheme.primary)),
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
