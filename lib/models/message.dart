import 'package:uuid/uuid.dart';

enum Role { user, bot }

class Message {
  final String id;
  final Role role;
  final List<MessageBlock> blocks;
  final DateTime createdAt;
  bool isEditing;

  Message({String? id, required this.role, required this.blocks, DateTime? createdAt, this.isEditing = false})
    : id = id ?? const Uuid().v4(),
      createdAt = createdAt ?? DateTime.now();

  Message copyWith({String? id, Role? role, List<MessageBlock>? blocks, DateTime? createdAt, bool? isEditing}) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      blocks: blocks ?? this.blocks,
      createdAt: createdAt ?? this.createdAt,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.toString().split('.').last,
      'blocks': blocks.map((block) => block.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isEditing': isEditing,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: Role.values.firstWhere((role) => role.toString().split('.').last == json['role'], orElse: () => Role.user),
      blocks: (json['blocks'] as List).map((blockJson) => MessageBlock.fromJson(blockJson)).toList(),
      createdAt: DateTime.parse(json['createdAt']),
      isEditing: json['isEditing'] ?? false,
    );
  }
}

abstract class MessageBlock {
  final String id;

  MessageBlock({String? id}) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson();

  factory MessageBlock.fromJson(Map<String, dynamic> json) {
    final String type = json['type'];

    switch (type) {
      case 'text':
        return TextBlock.fromJson(json);
      case 'toolCall':
        return ToolCallBlock.fromJson(json);
      default:
        throw Exception('Unknown block type: $type');
    }
  }
}

class TextBlock extends MessageBlock {
  final String text;

  TextBlock({required this.text, String? id}) : super(id: id);

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'type': 'text', 'text': text};
  }

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    return TextBlock(id: json['id'], text: json['text']);
  }
}

class ToolCallBlock extends MessageBlock {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String? result;

  ToolCallBlock({required this.toolName, required this.parameters, this.result, String? id}) : super(id: id);

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'type': 'toolCall', 'toolName': toolName, 'parameters': parameters, 'result': result};
  }

  factory ToolCallBlock.fromJson(Map<String, dynamic> json) {
    return ToolCallBlock(id: json['id'], toolName: json['toolName'], parameters: json['parameters'], result: json['result']);
  }

  ToolCallBlock copyWith({String? toolName, Map<String, dynamic>? parameters, String? result}) {
    return ToolCallBlock(id: id, toolName: toolName ?? this.toolName, parameters: parameters ?? this.parameters, result: result ?? this.result);
  }
}
