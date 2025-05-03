import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/conversation.dart';
import 'package:nexon/models/folder.dart';
import 'package:nexon/providers/conversation_provider.dart';
import 'package:intl/intl.dart';

class ChatHistorySidebar extends ConsumerWidget {
  const ChatHistorySidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final foldersAsync = ref.watch(foldersProvider);
    final currentConversationId = ref.watch(currentConversationIdProvider);

    return Drawer(
      elevation: 1.0,
      width: 280,
      child: Column(
        children: [
          _buildHeader(context, ref),
          const Divider(height: 1),
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                if (conversations.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildConversationList(context, ref, conversations, currentConversationId);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Chat History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Create new chat action
              final notifier = ref.read(conversationNotifierProvider.notifier);
              notifier
                  .createNewConversation(
                    title: 'New Chat',
                    aiProviderId: 'gemini', // Default provider
                    modelId: 'gemini-pro', // Default model
                  )
                  .then((id) {
                    if (id != null) {
                      ref.read(currentConversationIdProvider.notifier).state = id;
                    }
                  });
            },
            tooltip: 'New Chat',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No conversations yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Start a new chat to begin', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildConversationList(BuildContext context, WidgetRef ref, List<Conversation> conversations, String? currentId) {
    final dateFormat = DateFormat('MMM d, yyyy');

    // Group conversations by date
    final Map<String, List<Conversation>> grouped = {};
    for (var conversation in conversations) {
      final date = dateFormat.format(conversation.updatedAt);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(conversation);
    }

    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final dateConversations = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                date,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
            ...dateConversations.map((conversation) {
              final isSelected = conversation.id == currentId;
              return _buildConversationItem(context, ref, conversation, isSelected);
            }),
          ],
        );
      },
    );
  }

  Widget _buildConversationItem(BuildContext context, WidgetRef ref, Conversation conversation, bool isSelected) {
    final timeFormat = DateFormat('h:mm a');
    final time = timeFormat.format(conversation.updatedAt);

    return ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Row(
        children: [
          Icon(Icons.access_time, size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(time, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(width: 8),
          if (conversation.tags.isNotEmpty) ...[
            Icon(Icons.label_outline, size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(
              conversation.tags.first,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      onTap: () {
        ref.read(currentConversationIdProvider.notifier).state = conversation.id;
      },
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        onSelected: (value) async {
          if (value == 'delete') {
            // Show confirmation dialog
            final shouldDelete = await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Delete Conversation'),
                    content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCEL')),
                      TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('DELETE')),
                    ],
                  ),
            );

            if (shouldDelete == true) {
              ref.read(conversationNotifierProvider.notifier).deleteConversation(conversation.id);
            }
          } else if (value == 'rename') {
            // Show rename dialog
            final controller = TextEditingController(text: conversation.title);
            final newTitle = await showDialog<String>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Rename Conversation'),
                    content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Title'), autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
                      TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('RENAME')),
                    ],
                  ),
            );

            if (newTitle != null && newTitle.isNotEmpty) {
              final updated = conversation.copyWith(title: newTitle);
              ref.read(conversationNotifierProvider.notifier).updateConversation(updated);
            }
          }
        },
        itemBuilder:
            (context) => [
              const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Rename')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('Delete')])),
            ],
      ),
    );
  }
}
