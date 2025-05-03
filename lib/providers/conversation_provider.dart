import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/conversation.dart';
import 'package:nexon/models/folder.dart';
import 'package:nexon/models/message.dart';
import 'package:nexon/models/tag.dart';
import 'package:nexon/providers/database_provider.dart';

// Current conversation ID
final currentConversationIdProvider = StateProvider<String?>((ref) => null);

// Conversations by status
final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final repository = ref.watch(conversationRepositoryProvider);
  return repository.getAllConversations();
});

// Current conversation
final currentConversationProvider = FutureProvider<Conversation?>((ref) async {
  final repository = ref.watch(conversationRepositoryProvider);
  final conversationId = ref.watch(currentConversationIdProvider);

  if (conversationId == null) return null;
  return repository.getConversationById(conversationId);
});

// Current conversation messages
final conversationMessagesProvider = FutureProvider<List<Message>>((ref) async {
  final repository = ref.watch(conversationRepositoryProvider);
  final conversationId = ref.watch(currentConversationIdProvider);

  if (conversationId == null) return [];
  return repository.getMessagesForConversation(conversationId);
});

// Folders
final foldersProvider = FutureProvider<List<Folder>>((ref) async {
  final repository = ref.watch(conversationRepositoryProvider);
  return repository.getAllFolders();
});

// Tags
final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final repository = ref.watch(conversationRepositoryProvider);
  return repository.getAllTags();
});

// Conversations by folder
final conversationsByFolderProvider = FutureProvider.family<List<Conversation>, String>((ref, folderId) async {
  final repository = ref.watch(conversationRepositoryProvider);
  return repository.getConversationsByFolder(folderId);
});

// Conversations by tag
final conversationsByTagProvider = FutureProvider.family<List<Conversation>, String>((ref, tagId) async {
  final repository = ref.watch(conversationRepositoryProvider);
  return repository.getConversationsByTag(tagId);
});

class ConversationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ConversationNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<String?> createNewConversation({
    required String title,
    required String aiProviderId,
    required String modelId,
    String? folderId,
    List<String>? tags,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(conversationRepositoryProvider);

      final conversation = Conversation(title: title, aiProviderId: aiProviderId, modelId: modelId, folderId: folderId ?? '', tags: tags ?? []);

      final id = await repository.createConversation(conversation);
      _ref.invalidate(conversationsProvider);
      if (folderId != null) {
        _ref.invalidate(conversationsByFolderProvider(folderId));
      }

      state = const AsyncValue.data(null);
      return id;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<void> updateConversation(Conversation conversation) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(conversationRepositoryProvider);
      await repository.updateConversation(conversation);

      _ref.invalidate(conversationsProvider);
      _ref.invalidate(currentConversationProvider);
      if (conversation.folderId.isNotEmpty) {
        _ref.invalidate(conversationsByFolderProvider(conversation.folderId));
      }

      // Invalidate tag-based providers if needed
      for (final tag in conversation.tags) {
        // We would need tag ID here, but we have tag name
        // This is a simplification; in practice you might need to
        // lookup tag ID or invalidate all tag providers
      }

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteConversation(String id, {String? folderId}) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(conversationRepositoryProvider);

      // Get conversation first to know its folder
      final conversation = await repository.getConversationById(id);
      final conversationFolderId = conversation?.folderId;

      await repository.deleteConversation(id);

      // Clear current conversation if it was deleted
      final currentId = _ref.read(currentConversationIdProvider);
      if (currentId == id) {
        _ref.read(currentConversationIdProvider.notifier).state = null;
      }

      _ref.invalidate(conversationsProvider);

      // Invalidate folder provider if needed
      if (conversationFolderId != null && conversationFolderId.isNotEmpty) {
        _ref.invalidate(conversationsByFolderProvider(conversationFolderId));
      }

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addMessageToCurrentConversation(Message message) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(conversationRepositoryProvider);
      final conversationId = _ref.read(currentConversationIdProvider);

      if (conversationId == null) {
        throw Exception('No conversation selected');
      }

      // Get current messages to determine order index
      final messages = await repository.getMessagesForConversation(conversationId);
      final orderIndex = messages.length;

      await repository.addMessageToConversation(conversationId, message, orderIndex);

      _ref.invalidate(conversationMessagesProvider);
      _ref.invalidate(currentConversationProvider); // For updated timestamp

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateMessage(Message message) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(conversationRepositoryProvider);
      final conversationId = _ref.read(currentConversationIdProvider);

      if (conversationId == null) {
        throw Exception('No conversation selected');
      }

      await repository.updateMessage(conversationId, message);

      _ref.invalidate(conversationMessagesProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final conversationNotifierProvider = StateNotifierProvider<ConversationNotifier, AsyncValue<void>>((ref) {
  return ConversationNotifier(ref);
});
