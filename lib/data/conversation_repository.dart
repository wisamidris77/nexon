import 'package:drift/drift.dart';
import 'package:nexon/data/database.dart' as data;
import 'package:nexon/models/conversation.dart' as model;
import 'package:nexon/models/message.dart' as model;
import 'package:nexon/models/folder.dart' as model;
import 'package:nexon/models/tag.dart' as model;
import 'package:flutter/foundation.dart';

class ConversationRepository {
  final data.AppDatabase _db;

  ConversationRepository(this._db);

  // Conversations
  Future<List<model.Conversation>> getAllConversations() async {
    final query = _db.select(_db.conversations)..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);

    final rows = await query.get();
    final List<Future<model.Conversation>> conversions = rows.map((row) => _mapToConversation(row)).toList();
    return Future.wait(conversions);
  }

  Future<List<model.Conversation>> getConversationsByFolder(String folderId) async {
    final query =
        _db.select(_db.conversations)
          ..where((t) => t.folderId.equals(folderId))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);

    final rows = await query.get();
    final List<Future<model.Conversation>> conversions = rows.map((row) => _mapToConversation(row)).toList();
    return Future.wait(conversions);
  }

  Future<List<model.Conversation>> getConversationsByTag(String tagId) async {
    final query =
        (_db.select(_db.conversations).join([innerJoin(_db.conversationTags, _db.conversationTags.conversationId.equalsExp(_db.conversations.id))]))
          ..where(_db.conversationTags.tagId.equals(tagId))
          ..orderBy([OrderingTerm(expression: _db.conversations.updatedAt, mode: OrderingMode.desc)]);

    final rows = await query.get();
    final List<Future<model.Conversation>> conversions = rows.map((row) => _mapToConversation(row.readTable(_db.conversations))).toList();
    return Future.wait(conversions);
  }

  Future<model.Conversation?> getConversationById(String id) async {
    final query = _db.select(_db.conversations)..where((t) => t.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _mapToConversation(row);
  }

  Future<String> createConversation(model.Conversation conversation) async {
    return await _db.transaction(() async {
      final id = await _db
          .into(_db.conversations)
          .insert(
            data.ConversationsCompanion.insert(
              id: Value(conversation.id),
              title: conversation.title,
              createdAt: Value(conversation.createdAt),
              updatedAt: Value(conversation.updatedAt),
              folderId: Value(conversation.folderId.isEmpty ? null : conversation.folderId),
              status: Value(conversation.status.toString().split('.').last),
              aiProviderId: conversation.aiProviderId,
              modelId: conversation.modelId,
            ),
          );

      // Insert tags if provided
      if (conversation.tags.isNotEmpty) {
        for (final tagName in conversation.tags) {
          // Get or create tag
          final tag = await _getOrCreateTag(tagName);
          // Link conversation to tag
          await _db.into(_db.conversationTags).insert(data.ConversationTagsCompanion.insert(conversationId: conversation.id, tagId: tag.id));
        }
      }

      return conversation.id;
    });
  }

  Future<void> updateConversation(model.Conversation conversation) async {
    await _db.transaction(() async {
      await (_db.update(_db.conversations)..where((t) => t.id.equals(conversation.id))).write(
        data.ConversationsCompanion(
          title: Value(conversation.title),
          updatedAt: Value(DateTime.now()),
          folderId: Value(conversation.folderId.isEmpty ? null : conversation.folderId),
          status: Value(conversation.status.toString().split('.').last),
          aiProviderId: Value(conversation.aiProviderId),
          modelId: Value(conversation.modelId),
        ),
      );

      // Update tags by removing all and re-adding
      await (_db.delete(_db.conversationTags)..where((t) => t.conversationId.equals(conversation.id))).go();

      // Insert tags if provided
      if (conversation.tags.isNotEmpty) {
        for (final tagName in conversation.tags) {
          // Get or create tag
          final tag = await _getOrCreateTag(tagName);
          // Link conversation to tag
          await _db.into(_db.conversationTags).insert(data.ConversationTagsCompanion.insert(conversationId: conversation.id, tagId: tag.id));
        }
      }
    });
  }

  Future<void> deleteConversation(String id) async {
    await _db.transaction(() async {
      // Delete messages (cascade will delete message blocks)
      await (_db.delete(_db.messages)..where((t) => t.conversationId.equals(id))).go();

      // Delete conversation tags
      await (_db.delete(_db.conversationTags)..where((t) => t.conversationId.equals(id))).go();

      // Delete conversation
      await (_db.delete(_db.conversations)..where((t) => t.id.equals(id))).go();
    });
  }

  // Messages
  Future<List<model.Message>> getMessagesForConversation(String conversationId) async {
    final messagesQuery =
        _db.select(_db.messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);

    final messages = await messagesQuery.get();
    final result = <model.Message>[];

    for (final message in messages) {
      final blocksQuery =
          _db.select(_db.messageBlocks)
            ..where((t) => t.messageId.equals(message.id))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);

      final blocks = await blocksQuery.get();
      final messageBlocks =
          blocks.map((b) {
            if (b.type == 'text') {
              return model.TextBlock(text: b.content);
            } else if (b.type == 'toolCall') {
              final data = b.content.split('|||');
              if (data.length >= 3) {
                return model.ToolCallBlock(toolName: data[0], parameters: {'data': data[1]}, result: data[2].isEmpty ? null : data[2]);
              }
              return model.TextBlock(text: "Invalid tool call data");
            } else {
              return model.TextBlock(text: "Unknown block type: ${b.type}");
            }
          }).toList();

      result.add(
        model.Message(
          id: message.id,
          role: message.role == 'user' ? model.Role.user : model.Role.bot,
          blocks: messageBlocks,
          createdAt: message.createdAt,
        ),
      );
    }

    return result;
  }

  Future<void> addMessageToConversation(String conversationId, model.Message message, int orderIndex) async {
    await _db.transaction(() async {
      // Insert message
      final messageId = await _db
          .into(_db.messages)
          .insert(
            data.MessagesCompanion.insert(
              id: Value(message.id),
              conversationId: conversationId,
              role: message.role.toString().split('.').last,
              createdAt: Value(message.createdAt),
              orderIndex: orderIndex,
            ),
          );

      // Insert message blocks
      for (var i = 0; i < message.blocks.length; i++) {
        final block = message.blocks[i];
        String content;
        String type;

        if (block is model.TextBlock) {
          type = 'text';
          content = block.text;
        } else if (block is model.ToolCallBlock) {
          type = 'toolCall';
          content = '${block.toolName}|||${block.parameters['data'] ?? ''}|||${block.result ?? ''}';
        } else {
          type = 'unknown';
          content = 'Unknown block type';
        }

        await _db
            .into(_db.messageBlocks)
            .insert(data.MessageBlocksCompanion.insert(id: Value(block.id), messageId: message.id, type: type, content: content, orderIndex: i));
      }

      // Update conversation's lastUpdated time
      await (_db.update(_db.conversations)
        ..where((t) => t.id.equals(conversationId))).write(data.ConversationsCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  Future<void> updateMessage(String conversationId, model.Message message) async {
    await _db.transaction(() async {
      // Delete existing blocks
      await (_db.delete(_db.messageBlocks)..where((t) => t.messageId.equals(message.id))).go();

      // Insert new blocks
      for (var i = 0; i < message.blocks.length; i++) {
        final block = message.blocks[i];
        String content;
        String type;

        if (block is model.TextBlock) {
          type = 'text';
          content = block.text;
        } else if (block is model.ToolCallBlock) {
          type = 'toolCall';
          content = '${block.toolName}|||${block.parameters['data'] ?? ''}|||${block.result ?? ''}';
        } else {
          type = 'unknown';
          content = 'Unknown block type';
        }

        await _db
            .into(_db.messageBlocks)
            .insert(data.MessageBlocksCompanion.insert(id: Value(block.id), messageId: message.id, type: type, content: content, orderIndex: i));
      }

      // Update conversation's lastUpdated time
      await (_db.update(_db.conversations)
        ..where((t) => t.id.equals(conversationId))).write(data.ConversationsCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  // Folders
  Future<List<model.Folder>> getAllFolders() async {
    final query = _db.select(_db.folders)..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);

    final rows = await query.get();
    return rows.map((row) => _mapToFolder(row)).toList();
  }

  Future<model.Folder> createFolder(model.Folder folder) async {
    await _db
        .into(_db.folders)
        .insert(
          data.FoldersCompanion.insert(
            id: Value(folder.id),
            name: folder.name,
            parentId: Value(folder.parentId),
            createdAt: Value(folder.createdAt),
            orderIndex: Value(folder.orderIndex),
            iconName: Value(folder.iconName),
            colorHex: Value(folder.colorHex),
          ),
        );

    return folder;
  }

  Future<void> updateFolder(model.Folder folder) async {
    await (_db.update(_db.folders)..where((t) => t.id.equals(folder.id))).write(
      data.FoldersCompanion(
        name: Value(folder.name),
        parentId: Value(folder.parentId),
        orderIndex: Value(folder.orderIndex),
        iconName: Value(folder.iconName),
        colorHex: Value(folder.colorHex),
      ),
    );
  }

  Future<void> deleteFolder(String id) async {
    await _db.transaction(() async {
      // Move conversations to null folder
      await (_db.update(_db.conversations)..where((t) => t.folderId.equals(id))).write(const data.ConversationsCompanion(folderId: Value(null)));

      // Update child folders to null parent
      await (_db.update(_db.folders)..where((t) => t.parentId.equals(id))).write(const data.FoldersCompanion(parentId: Value(null)));

      // Delete folder
      await (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go();
    });
  }

  // Tags
  Future<List<model.Tag>> getAllTags() async {
    final query = _db.select(_db.tags)..orderBy([(t) => OrderingTerm(expression: t.name)]);

    final rows = await query.get();
    return rows.map((row) => _mapToTag(row)).toList();
  }

  Future<model.Tag> createTag(model.Tag tag) async {
    await _db
        .into(_db.tags)
        .insert(data.TagsCompanion.insert(id: Value(tag.id), name: tag.name, colorHex: Value(tag.colorHex), createdAt: Value(tag.createdAt)));

    return tag;
  }

  Future<void> updateTag(model.Tag tag) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(data.TagsCompanion(name: Value(tag.name), colorHex: Value(tag.colorHex)));
  }

  Future<void> deleteTag(String id) async {
    await _db.transaction(() async {
      // Delete tag from all conversations
      await (_db.delete(_db.conversationTags)..where((t) => t.tagId.equals(id))).go();

      // Delete tag
      await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
    });
  }

  // Helper methods
  Future<model.Conversation> _mapToConversation(data.Conversation row) async {
    // Get tags for this conversation
    final tagsQuery = (_db.select(_db.tags).join([innerJoin(_db.conversationTags, _db.conversationTags.tagId.equalsExp(_db.tags.id))]))
      ..where(_db.conversationTags.conversationId.equals(row.id));

    final tagsRows = await tagsQuery.get();
    final tags = tagsRows.map((row) => row.readTable(_db.tags).name).toList();

    return model.Conversation(
      id: row.id,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      folderId: row.folderId ?? '',
      tags: tags,
      status: model.ConversationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == row.status,
        orElse: () => model.ConversationStatus.active,
      ),
      aiProviderId: row.aiProviderId,
      modelId: row.modelId,
    );
  }

  model.Folder _mapToFolder(data.Folder row) {
    return model.Folder(
      id: row.id,
      name: row.name,
      parentId: row.parentId,
      createdAt: row.createdAt,
      orderIndex: row.orderIndex,
      iconName: row.iconName,
      colorHex: row.colorHex,
    );
  }

  model.Tag _mapToTag(data.Tag row) {
    return model.Tag(id: row.id, name: row.name, colorHex: row.colorHex, createdAt: row.createdAt);
  }

  Future<model.Tag> _getOrCreateTag(String name) async {
    // Try to find existing tag
    final query = _db.select(_db.tags)..where((t) => t.name.equals(name));
    final existing = await query.getSingleOrNull();

    if (existing != null) {
      return _mapToTag(existing);
    }

    // Create new tag
    final tag = model.Tag(name: name);
    await _db
        .into(_db.tags)
        .insert(data.TagsCompanion.insert(id: Value(tag.id), name: tag.name, colorHex: Value(tag.colorHex), createdAt: Value(tag.createdAt)));

    return tag;
  }
}
