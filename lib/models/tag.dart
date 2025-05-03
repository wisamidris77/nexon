import 'package:uuid/uuid.dart';

class Tag {
  final String id;
  final String name;
  final String colorHex;
  final DateTime createdAt;

  Tag({
    String? id,
    required this.name,
    this.colorHex = '#4A8CDC', // Default electric blue
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Tag copyWith({String? id, String? name, String? colorHex, DateTime? createdAt}) {
    return Tag(id: id ?? this.id, name: name ?? this.name, colorHex: colorHex ?? this.colorHex, createdAt: createdAt ?? this.createdAt);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'colorHex': colorHex, 'createdAt': createdAt.toIso8601String()};
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(id: json['id'], name: json['name'], colorHex: json['colorHex'] ?? '#4A8CDC', createdAt: DateTime.parse(json['createdAt']));
  }
}
