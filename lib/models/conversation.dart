import 'package:uuid/uuid.dart';
import 'package:nexon/models/message.dart';

enum ConversationStatus { active, archived, deleted }

class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String folderId;
  final ConversationStatus status;
  final String aiProviderId;
  final String modelId;

  Conversation({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    this.folderId = '',
    this.status = ConversationStatus.active,
    required this.aiProviderId,
    required this.modelId,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       tags = tags ?? [];

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? folderId,
    ConversationStatus? status,
    String? aiProviderId,
    String? modelId,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      folderId: folderId ?? this.folderId,
      status: status ?? this.status,
      aiProviderId: aiProviderId ?? this.aiProviderId,
      modelId: modelId ?? this.modelId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'folderId': folderId,
      'status': status.toString().split('.').last,
      'aiProviderId': aiProviderId,
      'modelId': modelId,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      tags: List<String>.from(json['tags'] ?? []),
      folderId: json['folderId'] ?? '',
      status: ConversationStatus.values.firstWhere((e) => e.toString().split('.').last == json['status'], orElse: () => ConversationStatus.active),
      aiProviderId: json['aiProviderId'],
      modelId: json['modelId'],
    );
  }
}
