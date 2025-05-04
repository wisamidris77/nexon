import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nexon/models/conversation.dart';
import 'package:nexon/models/message.dart';
import 'package:nexon/models/ai_provider.dart';
import 'package:nexon/models/ai_settings.dart';
import 'package:nexon/providers/conversation_provider.dart';
import 'package:nexon/providers/database_provider.dart';
import 'package:nexon/providers/settings_provider.dart';
import 'package:nexon/providers/chat_provider.dart' hide aiSettingsProvider;
import 'package:nexon/services/ai_service.dart';

class ConversationDetailScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  final bool isTemporary;
  final Function(String conversationId)? onFirstMessageSent;

  const ConversationDetailScreen({Key? key, this.conversationId, this.isTemporary = false, this.onFirstMessageSent}) : super(key: key);

  @override
  ConsumerState<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends ConsumerState<ConversationDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _tempChatMessageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _tempChatFocusNode = FocusNode();
  bool _isGenerating = false;
  AIService? _currentAIService;

  @override
  void initState() {
    super.initState();
    // Set the current conversation if not temporary
    if (!widget.isTemporary && widget.conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentConversationIdProvider.notifier).state = widget.conversationId;
      });
    }

    // Set up keyboard listeners for Enter key handling
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);
      } else {
        ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
      }
    });

    _tempChatFocusNode.addListener(() {
      if (_tempChatFocusNode.hasFocus) {
        ServicesBinding.instance.keyboard.addHandler(_handleTempChatKeyEvent);
      } else {
        ServicesBinding.instance.keyboard.removeHandler(_handleTempChatKeyEvent);
      }
    });
  }

  @override
  void dispose() {
    // Remove key event handlers
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
    ServicesBinding.instance.keyboard.removeHandler(_handleTempChatKeyEvent);

    _scrollController.dispose();
    _messageController.dispose();
    _tempChatMessageController.dispose();
    _focusNode.dispose();
    _tempChatFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _sendMessage() async {
    // Use the appropriate controller based on whether this is a temporary chat
    final controller = widget.isTemporary ? _tempChatMessageController : _messageController;
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isGenerating = true);

    // Create user message - Fix by using text.trim() again to ensure no extra whitespace
    final userMessage = Message(role: Role.user, blocks: [TextBlock(text: text.trim())]);

    // First message in a temporary chat - create a new conversation
    if (widget.isTemporary) {
      final notifier = ref.read(conversationNotifierProvider.notifier);

      // Get up to 20 characters for the title, without breaking words if possible
      String title =
          text.length <= 20
              ? text
              : (text.substring(0, 20).lastIndexOf(' ') > 5 ? text.substring(0, text.substring(0, 20).lastIndexOf(' ')) : text.substring(0, 20));

      final newConversationId = await notifier.createNewConversation(
        title: title,
        aiProviderId: 'gemini', // Default provider
        modelId: 'gemini-pro', // Default model
      );

      if (newConversationId != null) {
        // Add message to the new conversation
        await ref.read(conversationRepositoryProvider).addMessageToConversation(newConversationId, userMessage, 0);

        // Notify parent about the new conversation
        if (widget.onFirstMessageSent != null) {
          widget.onFirstMessageSent!(newConversationId);
        }

        // Generate bot response
        _generateResponse(text, newConversationId);
      } else {
        // Handle error creating conversation
        setState(() => _isGenerating = false);
      }
    } else if (widget.conversationId != null) {
      // Add message to existing conversation
      await ref.read(conversationNotifierProvider.notifier).addMessageToCurrentConversation(userMessage);

      // Generate bot response
      _generateResponse(text, widget.conversationId!);
    }

    controller.clear();
  }

  void _generateResponse(String userText, String conversationId) async {
    try {
      // Get the conversation to access the model information
      final conversation = await ref.read(conversationRepositoryProvider).getConversationById(conversationId);
      if (conversation == null) {
        setState(() => _isGenerating = false);
        return;
      }

      // Get all messages for this conversation
      final messages = await ref.read(conversationRepositoryProvider).getMessagesForConversation(conversationId);

      // Get AI settings from our AIProviderSettings provider
      final aiProviderSettings = ref.read(aiSettingsProvider);

      // Create settings object for the AI service
      final aiProvider = AIProvider.values.firstWhere(
        (p) => p.toString().split('.').last == conversation.aiProviderId,
        orElse: () => AIProvider.gemini,
      );

      final model = AIModels.getAllModels().firstWhere(
        (m) => m.id == conversation.modelId && m.provider == aiProvider,
        orElse: () => AIModels.getDefaultModel(),
      );

      final providerKey = aiProvider.toString().split('.').last;
      final settings = AISettings(
        apiKey: aiProviderSettings.apiKeys[providerKey] ?? '',
        selectedModel: model,
        temperature: aiProviderSettings.temperature,
        maxTokens: aiProviderSettings.maxTokens,
        topP: aiProviderSettings.topP,
      );

      // Log for debugging
      print('Using API key for $providerKey: ${settings.apiKey.isNotEmpty ? "API key found" : "No API key"}');

      // Create AI service based on provider
      _currentAIService = AIService.create(aiProvider);

      // Generate response
      final responseStream = await _currentAIService!.generateStreamResponse(messages, settings);

      // Create a new bot message
      String responseText = '';
      final botMessage = Message(role: Role.bot, blocks: [TextBlock(text: responseText)]);

      // Add empty bot message to the conversation
      await ref.read(conversationRepositoryProvider).addMessageToConversation(conversationId, botMessage, messages.length);

      // Stream and update the response
      await for (final chunk in responseStream) {
        if (!mounted) break;

        responseText += chunk;

        // Update the bot message with the latest text
        final updatedBotMessage = Message(
          id: botMessage.id,
          role: Role.bot,
          blocks: [TextBlock(text: responseText)],
          createdAt: botMessage.createdAt,
        );

        await ref.read(conversationRepositoryProvider).updateMessage(conversationId, updatedBotMessage);

        // Refresh the messages
        ref.invalidate(conversationMessagesProvider);
      }

      // Scroll to bottom to show new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      // Handle error
      print('Error generating response: $e');

      if (mounted) {
        // Add error message
        final errorMessage = Message(role: Role.bot, blocks: [TextBlock(text: 'Error: ${e.toString()}')]);
        await ref.read(conversationRepositoryProvider).addMessageToConversation(conversationId, errorMessage, 1);
        ref.invalidate(conversationMessagesProvider);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        _currentAIService = null;
      }
    }
  }

  Future<void> _stopGenerating() async {
    if (_currentAIService != null) {
      await _currentAIService!.stopGeneration();
      _currentAIService = null;
    }

    if (mounted) {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If it's a temporary chat, show empty state
    if (widget.isTemporary) {
      return _buildTemporaryChat(context);
    }

    final conversationAsync = ref.watch(currentConversationProvider);
    final messagesAsync = ref.watch(conversationMessagesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Get debug mode from settings
    final debugMode = ref.watch(settingsProvider.select((s) => s.debugMode));

    return Scaffold(
      body: Column(
        children: [
          // Debug info button only shown in debug mode
          if (debugMode)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, right: 4.0),
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Conversation details',
                  onPressed: () {
                    _showConversationDetails(context, ref);
                  },
                ),
              ),
            ),

          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return _buildEmptyState(context);
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (messages.isNotEmpty && _isGenerating) {
                    _scrollToBottom();
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message, context);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading messages: $error')),
            ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -1))],
            ),
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show generation indicator and stop button
                    if (_isGenerating)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: colorScheme.primaryContainer.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)),
                            const SizedBox(width: 16),
                            Text('Generating response...', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.stop_circle, color: colorScheme.error),
                              tooltip: 'Stop generating',
                              onPressed: _stopGenerating,
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            enabled: !_isGenerating,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            maxLines: null,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            onSubmitted: (text) {
                              if (text.trim().isNotEmpty && !_isGenerating) {
                                _sendMessage();
                              }
                            },
                            // Handle key events at TextField level instead of RawKeyboardListener
                            onEditingComplete: () {},
                            onChanged: (_) {},
                            // The key event handling is now done via a Focus widget below
                          ),
                        ),
                        const SizedBox(width: 12),
                        FloatingActionButton(
                          heroTag: 'send_message_fab',
                          onPressed: _isGenerating ? null : _sendMessage,
                          elevation: 0,
                          child:
                              _isGenerating
                                  ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimaryContainer),
                                  )
                                  : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, BuildContext context) {
    final isUser = message.role == Role.user;
    final colorScheme = Theme.of(context).colorScheme;

    // Get app settings for avatar and timestamp display
    final appSettings = ref.watch(settingsProvider);
    final showAvatars = appSettings.showAvatars;
    final showTimestamps = appSettings.showTimestamps;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser && showAvatars)
            CircleAvatar(
              backgroundColor: colorScheme.primary.withOpacity(0.2),
              radius: 18,
              child: Icon(Icons.smart_toy, color: colorScheme.primary, size: 20),
            ),

          const SizedBox(width: 12),

          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isUser ? colorScheme.primaryContainer : colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(!isUser ? 4 : 16),
                    topRight: Radius.circular(isUser ? 4 : 16),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: const Radius.circular(16),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...message.blocks.map((block) {
                      if (block is TextBlock) {
                        try {
                          return MarkdownBody(
                            data: block.text,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(color: isUser ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant, fontSize: 15, height: 1.5),
                              code: TextStyle(
                                backgroundColor: isUser ? colorScheme.primary.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: isUser ? colorScheme.primary.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              blockSpacing: 12,
                            ),
                          );
                        } catch (e) {
                          // Fallback to simple selectable text if markdown throws an error
                          return SelectableText(
                            block.text,
                            style: TextStyle(
                              color: isUser ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          );
                        }
                      } else if (block is ToolCallBlock) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tool Call: ${block.toolName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if (block.result != null) ...[
                                  const Divider(),
                                  Text('Result:', style: const TextStyle(fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 4),
                                  Text(block.result!),
                                ],
                              ],
                            ),
                          ),
                        );
                      } else {
                        return const Text('Unsupported block type');
                      }
                    }).toList(),

                    // Timestamp - only show if enabled in settings
                    if (showTimestamps)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          DateFormat('h:mm a').format(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isUser ? colorScheme.onPrimaryContainer.withOpacity(0.6) : colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          if (isUser && showAvatars)
            CircleAvatar(backgroundColor: colorScheme.primaryContainer, radius: 18, child: Icon(Icons.person, color: colorScheme.primary, size: 20)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 72, color: colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            'Start a new conversation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onBackground),
          ),
          const SizedBox(height: 12),
          Text(
            'Type a message below to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  void _showConversationDetails(BuildContext context, WidgetRef ref) {
    final conversationAsync = ref.watch(currentConversationProvider);

    if (conversationAsync is AsyncData && conversationAsync.value != null) {
      final conversation = conversationAsync.value!;

      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conversation Details', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildDetailRow('Title', conversation.title),
                _buildDetailRow('Created', DateFormat.yMMMd().format(conversation.createdAt)),
                _buildDetailRow('Updated', DateFormat.yMMMd().add_jm().format(conversation.updatedAt)),
                _buildDetailRow('Model', conversation.modelId),
                _buildDetailRow('Provider', conversation.aiProviderId),
                if (conversation.tags.isNotEmpty) _buildDetailRow('Tags', conversation.tags.join(', ')),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Rename'),
                      onPressed: () {
                        Navigator.pop(context);
                        _showRenameDialog(context, ref, conversation);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(context, ref, conversation);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text(value))],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Conversation conversation) {
    final controller = TextEditingController(text: conversation.title);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Conversation'),
            content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Title'), autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
              TextButton(
                onPressed: () {
                  final newTitle = controller.text.trim();
                  if (newTitle.isNotEmpty) {
                    final updated = conversation.copyWith(title: newTitle);
                    ref.read(conversationNotifierProvider.notifier).updateConversation(updated);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('RENAME'),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Conversation conversation) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(conversationNotifierProvider.notifier).deleteConversation(conversation.id);
                  Navigator.of(context).pop(); // Pop the conversation screen
                },
                child: const Text('DELETE'),
              ),
            ],
          ),
    );
  }

  Widget _buildTemporaryChat(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.w600)), elevation: 0),
      body: Column(
        children: [
          // Empty state
          Expanded(child: _buildEmptyState(context)),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -1))],
            ),
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show generation indicator and stop button
                    if (_isGenerating)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: colorScheme.primaryContainer.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)),
                            const SizedBox(width: 16),
                            Text('Generating response...', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.stop_circle, color: colorScheme.error),
                              tooltip: 'Stop generating',
                              onPressed: _stopGenerating,
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tempChatMessageController,
                            enabled: !_isGenerating,
                            focusNode: _tempChatFocusNode,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Type a message to start a new chat...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            maxLines: null,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            onSubmitted: (text) {
                              if (text.trim().isNotEmpty && !_isGenerating) {
                                _sendMessage();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FloatingActionButton(
                          heroTag: 'temp_chat_fab',
                          onPressed: _isGenerating ? null : _sendMessage,
                          elevation: 0,
                          child:
                              _isGenerating
                                  ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimaryContainer),
                                  )
                                  : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Handle keyboard events for main chat
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      // Shift+Enter: allow new line
      if (HardwareKeyboard.instance.isShiftPressed) {
        return false; // Let the default handler add a new line
      }
      // Regular Enter: send message
      else if (_messageController.text.trim().isNotEmpty && !_isGenerating) {
        _sendMessage();
        return true; // We handled this key
      }
    }
    return false; // Let other handlers process the event
  }

  // Handle keyboard events for temporary chat
  bool _handleTempChatKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      // Shift+Enter: allow new line
      if (HardwareKeyboard.instance.isShiftPressed) {
        return false; // Let the default handler add a new line
      }
      // Regular Enter: send message
      else if (_tempChatMessageController.text.trim().isNotEmpty && !_isGenerating) {
        _sendMessage();
        return true; // We handled this key
      }
    }
    return false; // Let other handlers process the event
  }
}
