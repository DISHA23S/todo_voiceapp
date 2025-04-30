import 'package:hive/hive.dart';
import '../models/todo_model.dart';

enum CommandType {
  create,
  update,
  delete,
  complete
}

class QueuedCommand {
  final CommandType type;
  final Todo todo;
  final DateTime timestamp;

  QueuedCommand({
    required this.type,
    required this.todo,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'todo': todo.toJson(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory QueuedCommand.fromJson(Map<String, dynamic> json) {
    return QueuedCommand(
      type: CommandType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      todo: Todo.fromJson(json['todo']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class QueueService {
  static const String _queueBoxName = 'command_queue';
  late Box<Map> _queueBox;

  Future<void> initialize() async {
    _queueBox = await Hive.openBox<Map>(_queueBoxName);
  }

  Future<void> addCommand(QueuedCommand command) async {
    await _queueBox.add(command.toJson());
  }

  List<QueuedCommand> getQueuedCommands() {
    return _queueBox.values
        .map((json) => QueuedCommand.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> clearQueue() async {
    await _queueBox.clear();
  }

  Future<void> removeCommand(int index) async {
    await _queueBox.deleteAt(index);
  }
} 