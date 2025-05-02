import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/message.dart';
import 'package:nexon/providers/chat_provider.dart';
import 'package:nexon/widgets/chat_input.dart';
import 'package:nexon/widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  // Scroll controller for auto-scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll to bottom of the chat
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isGenerating = ref.watch(isGeneratingProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Find if any message is being edited
    final editingMessage = messages.firstWhere((message) => message.isEditing, orElse: () => Message(role: Role.user, blocks: []));
    final isEditing = editingMessage.blocks.isNotEmpty;

    // Auto scroll when messages change and when generating
    if (messages.isNotEmpty && (isGenerating || messages.last.role == Role.bot)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexon Chat'),
        scrolledUnderElevation: 0,
        actions: [
          // Show a stop button in the app bar when generating
          if (isGenerating)
            IconButton(
              icon: Icon(Icons.stop_circle_rounded, color: colorScheme.error),
              tooltip: 'Stop generating',
              onPressed: () {
                ref.read(chatMessagesProvider.notifier).stopGeneration();
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: colorScheme.background,
          // Simple gradient pattern as fallback for the image
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.background, colorScheme.surfaceVariant.withOpacity(0.3)],
            stops: const [0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child:
                    messages.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          itemCount: messages.length,
                          reverse: false,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return MessageBubble(
                              message: message,
                              isGenerating: isGenerating && index == messages.length - 1 && message.role == Role.bot,
                              onEdit:
                                  message.role == Role.user
                                      ? () {
                                        ref.read(chatMessagesProvider.notifier).startEditingMessage(message.id);
                                      }
                                      : null,
                            );
                          },
                        ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [BoxShadow(color: colorScheme.shadow.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
                ),
                child: ChatInput(
                  onSendMessage: (text) {
                    ref.read(chatMessagesProvider.notifier).sendMessage(text);
                  },
                  isGenerating: isGenerating,
                  onStop: () {
                    ref.read(chatMessagesProvider.notifier).stopGeneration();
                  },
                  editingMessage: isEditing ? editingMessage : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.chat_rounded, size: 64, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colorScheme.onBackground, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            'Type a message or try a suggestion',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground.withOpacity(0.7)),
          ),
          const SizedBox(height: 32),

          // Quick prompt chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 12,
              children: [
                _buildQuickPromptChip(context, 'Say hello', Icons.waving_hand_rounded, 'Hi there! Can you introduce yourself?'),
                _buildQuickPromptChip(context, 'Tell a joke', Icons.sentiment_very_satisfied_rounded, 'Tell me a funny joke'),
                _buildQuickPromptChip(context, 'Daily tips', Icons.tips_and_updates_rounded, 'Give me three productivity tips for today'),
                _buildQuickPromptChip(
                  context,
                  'Explain something',
                  Icons.lightbulb_outline_rounded,
                  'Explain how artificial intelligence works in simple terms',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptChip(BuildContext context, String label, IconData icon, String promptText) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      label: Text(label, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
      avatar: Icon(icon, size: 18, color: colorScheme.primary),
      backgroundColor: colorScheme.surfaceVariant,
      elevation: 0,
      pressElevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colorScheme.primary.withOpacity(0.2))),
      onPressed: () {
        // Send the prompt text when chip is tapped
        ref.read(chatMessagesProvider.notifier).sendMessage(promptText);
      },
    );
  }
}
