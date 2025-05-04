import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/conversation.dart';
import 'package:nexon/models/message.dart'; // Import for Role and TextBlock
import 'package:nexon/models/folder.dart';
import 'package:nexon/models/tag.dart';
import 'package:nexon/providers/conversation_provider.dart';
import 'package:nexon/providers/database_provider.dart';
import 'package:nexon/providers/settings_provider.dart';
import 'package:nexon/data/conversation_repository.dart';
import 'package:intl/intl.dart';

class ChatHistorySidebar extends ConsumerStatefulWidget {
  final VoidCallback onNewChat;

  const ChatHistorySidebar({Key? key, required this.onNewChat}) : super(key: key);

  @override
  ConsumerState<ChatHistorySidebar> createState() => _ChatHistorySidebarState();
}

class _ChatHistorySidebarState extends ConsumerState<ChatHistorySidebar> {
  bool _showFolders = true;
  bool _showTags = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.drawerTheme.backgroundColor,
        border: Border(
          right: BorderSide(
            color: theme.brightness == Brightness.light 
                ? Colors.grey.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo and App Name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Nexon',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // New Chat Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton.icon(
              onPressed: widget.onNewChat,
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Section title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Conversations',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // All Chats
          Expanded(child: _buildConversationsList(ref, context)),

          // Settings
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: colorScheme.onSurfaceVariant),
            title: Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            dense: true,
            onTap: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),

          // Version number
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Nexon v1.0.0',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList(WidgetRef ref, BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a new chat to begin',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Filter conversations by search query
        final filteredConversations = _filterConversations(conversations, _searchQuery, ref);

        if (filteredConversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No matching conversations',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: filteredConversations.length,
          itemBuilder: (context, index) {
            final conversation = filteredConversations[index];
            return _buildConversationItem(conversation, ref, context);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading conversations',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Filter conversations by search query
  List<Conversation> _filterConversations(List<Conversation> conversations, String query, WidgetRef ref) {
    if (query.isEmpty) return conversations;

    // Get app settings to determine search behavior
    final appSettings = ref.read(settingsProvider);
    final searchInMessages = appSettings.searchInMessages;

    // Basic title search
    List<Conversation> results = conversations.where((c) => c.title.toLowerCase().contains(query.toLowerCase())).toList();

    // If search in messages is enabled, add those results
    if (searchInMessages && query.length >= 3) {
      // Only search messages for queries of 3+ chars
      // Get repository to search messages
      final repository = ref.read(conversationRepositoryProvider);

      // Process conversations not already in results
      for (final conversation in conversations) {
        if (!results.contains(conversation)) {
          repository.getMessagesForConversation(conversation.id).then((messages) {
            // Search in messages based on settings
            bool hasMatch = false;

            for (final message in messages) {
              // Only search in appropriate message types based on settings
              if ((message.role == Role.user && appSettings.searchInUserMessages) || (message.role == Role.bot && appSettings.searchInBotMessages)) {
                // Search in message text blocks
                for (final block in message.blocks) {
                  if (block is TextBlock) {
                    if (block.text.toLowerCase().contains(query.toLowerCase())) {
                      hasMatch = true;
                      break;
                    }
                  }
                }

                if (hasMatch) break;
              }
            }

            // If a match was found in messages, add the conversation to results
            if (hasMatch && !results.contains(conversation)) {
              results.add(conversation);
              // Force UI refresh by updating state
              if (mounted) setState(() {});
            }
          });
        }
      }
    }

    return results;
  }

  Widget _buildConversationItem(Conversation conversation, WidgetRef ref, BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formatter = DateFormat('MMM d');
    final timeFormatter = DateFormat('h:mm a');
    final currentId = ref.watch(currentConversationIdProvider);
    final isSelected = currentId == conversation.id;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? colorScheme.primaryContainer 
              : colorScheme.surfaceVariant,
          radius: 16,
          child: Icon(
            Icons.chat_outlined,
            size: 16,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withOpacity(0.8),
          ),
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                formatter.format(conversation.updatedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        trailing: SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            icon: Icon(
              Icons.more_horiz,
              size: 18,
              color: colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
            padding: EdgeInsets.zero,
            onPressed: () {
              _showConversationMenu(context, ref, conversation);
            },
          ),
        ),
        onTap: () {
          // Set current conversation
          ref.read(currentConversationIdProvider.notifier).state = conversation.id;
          // Close drawer on mobile
          if (MediaQuery.of(context).size.width < 800) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  void _showConversationMenu(BuildContext context, WidgetRef ref, Conversation conversation) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context, ref, conversation);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: colorScheme.error),
            title: Text('Delete', style: TextStyle(color: colorScheme.error)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteDialog(context, ref, conversation);
            },
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Conversation conversation) {
    final titleController = TextEditingController(text: conversation.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Enter a new title',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final updated = conversation.copyWith(title: title);
                ref.read(conversationRepositoryProvider).updateConversation(updated);
                ref.invalidate(conversationsProvider);
                Navigator.of(context).pop();
              }
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Conversation conversation) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              ref.read(conversationRepositoryProvider).deleteConversation(conversation.id);
              ref.invalidate(conversationsProvider);

              // If this was the current conversation, clear it
              final currentId = ref.read(currentConversationIdProvider);
              if (currentId == conversation.id) {
                ref.read(currentConversationIdProvider.notifier).state = null;
              }

              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
