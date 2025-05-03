import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/conversation.dart';
import 'package:nexon/models/folder.dart';
import 'package:nexon/models/tag.dart';
import 'package:nexon/providers/conversation_provider.dart';
import 'package:nexon/providers/database_provider.dart';
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
    // For now, we'll ignore folder and tag functionality
    // TODO: Implement folder and tag management in future iterations

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      child: Column(
        children: [
          // New Chat Button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              onPressed: widget.onNewChat,
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: TextFormField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 8.0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // All Chats
          Expanded(child: _buildConversationsList(ref, context)),

          // Settings
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildConversationsList(WidgetRef ref, BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return const Center(child: Text('No conversations yet'));
        }

        // Filter conversations by search query
        final filteredConversations =
            _searchQuery.isEmpty ? conversations : conversations.where((c) => c.title.toLowerCase().contains(_searchQuery)).toList();

        if (filteredConversations.isEmpty) {
          return const Center(child: Text('No matching conversations'));
        }

        return ListView.builder(
          itemCount: filteredConversations.length,
          itemBuilder: (context, index) {
            final conversation = filteredConversations[index];
            return _buildConversationItem(conversation, ref, context);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading conversations')),
    );
  }

  // Comment out folder and tag related widgets
  /*
  Widget _buildFoldersList(WidgetRef ref, BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);
    
    return foldersAsync.when(
      data: (folders) {
        if (folders.isEmpty) {
          return const Center(
            child: Text('No folders yet'),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            return _buildFolderItem(folder, ref, context);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading folders')),
    );
  }
  
  Widget _buildFolderItem(Folder folder, WidgetRef ref, BuildContext context) {
    return ExpansionTile(
      leading: Icon(
        Icons.folder,
        color: Color(int.parse(folder.colorHex.substring(1, 7), radix: 16) + 0xFF000000),
      ),
      title: Text(folder.name),
      initiallyExpanded: false,
      children: [
        // Conversations in the folder
        FutureBuilder<List<Conversation>>(
          future: ref.read(conversationRepositoryProvider).getConversationsByFolder(folder.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return const Text('Error loading conversations');
            }
            
            final conversations = snapshot.data ?? [];
            
            if (conversations.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No conversations in this folder'),
              );
            }
            
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return _buildConversationItem(conversation, ref, context);
              },
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildTagsList(WidgetRef ref, BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    
    return tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) {
          return const Center(
            child: Text('No tags yet'),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          itemCount: tags.length,
          itemBuilder: (context, index) {
            final tag = tags[index];
            return ListTile(
              leading: Icon(
                Icons.label,
                color: Color(int.parse(tag.colorHex.substring(1, 7), radix: 16) + 0xFF000000),
              ),
              title: Text(tag.name),
              onTap: () {
                // Show conversations with this tag
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading tags')),
    );
  }
  */

  Widget _buildConversationItem(Conversation conversation, WidgetRef ref, BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatter.format(conversation.updatedAt), style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
      trailing: PopupMenuButton(
        icon: const Icon(Icons.more_vert),
        itemBuilder:
            (context) => [const PopupMenuItem(value: 'rename', child: Text('Rename')), const PopupMenuItem(value: 'delete', child: Text('Delete'))],
        onSelected: (value) {
          // Handle selected action
          switch (value) {
            case 'rename':
              _showRenameDialog(context, ref, conversation);
              break;
            case 'delete':
              _showDeleteDialog(context, ref, conversation);
              break;
          }
        },
      ),
      onTap: () {
        // Set current conversation
        ref.read(currentConversationIdProvider.notifier).state = conversation.id;
        // Close drawer on mobile
        Navigator.of(context).pop();
        // No navigation to another route
      },
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Conversation conversation) {
    final titleController = TextEditingController(text: conversation.title);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Conversation'),
            content: TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title'), autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
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

  /*
  void _showMoveFolderDialog(BuildContext context, WidgetRef ref, Conversation conversation) {
    // Implementation for moving to folder dialog
  }
  */

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Conversation conversation) {
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
                  ref.read(conversationRepositoryProvider).deleteConversation(conversation.id);
                  ref.invalidate(conversationsProvider);

                  /* Comment out folder related code
              if (conversation.folderId.isNotEmpty) {
                ref.invalidate(conversationsByFolderProvider(conversation.folderId));
              }
              */

                  // If this was the current conversation, clear it
                  final currentId = ref.read(currentConversationIdProvider);
                  if (currentId == conversation.id) {
                    ref.read(currentConversationIdProvider.notifier).state = null;
                  }

                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );
  }
}
