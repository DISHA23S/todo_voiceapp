import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'todo_model.g.dart';

@HiveType(typeId: 0)
class Todo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final bool isCompleted;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final DateTime? completedAt;

  @HiveField(7)
  final bool isSynced;

  Todo({
    String? id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.isSynced = false,
  })  : this.id = id ?? const Uuid().v4(),
        this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? DateTime.now();

  Todo copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: completedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, description: $description, isCompleted: $isCompleted)';
  }
} 