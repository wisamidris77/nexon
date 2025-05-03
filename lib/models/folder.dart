import 'package:uuid/uuid.dart';

class Folder {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final int orderIndex;
  final String iconName;
  final String colorHex;

  Folder({
    String? id,
    required this.name,
    this.parentId,
    DateTime? createdAt,
    this.orderIndex = 0,
    this.iconName = 'folder',
    this.colorHex = '#4A8CDC', // Default electric blue
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Folder copyWith({String? id, String? name, String? parentId, DateTime? createdAt, int? orderIndex, String? iconName, String? colorHex}) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      orderIndex: orderIndex ?? this.orderIndex,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'orderIndex': orderIndex,
      'iconName': iconName,
      'colorHex': colorHex,
    };
  }

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
      name: json['name'],
      parentId: json['parentId'],
      createdAt: DateTime.parse(json['createdAt']),
      orderIndex: json['orderIndex'] ?? 0,
      iconName: json['iconName'] ?? 'folder',
      colorHex: json['colorHex'] ?? '#4A8CDC',
    );
  }
}
