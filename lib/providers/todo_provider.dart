import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/todo_model.dart';

final todoBoxProvider = FutureProvider<Box<Todo>>((ref) async {
  return Hive.box<Todo>('todos');
});

final todosProvider = StateNotifierProvider<TodosNotifier, List<Todo>>((ref) {
  final box = ref.watch(todoBoxProvider).value;
  return TodosNotifier(box);
});

class TodosNotifier extends StateNotifier<List<Todo>> {
  final Box<Todo>? _box;

  TodosNotifier(this._box) : super(_box?.values.toList() ?? []) {
    _box?.watch().listen((event) {
      state = _box?.values.toList() ?? [];
    });
  }

  void addTodo(Todo todo) {
    _box?.put(todo.id, todo);
  }

  void updateTodo(Todo todo) {
    _box?.put(todo.id, todo);
  }

  void deleteTodo(String id) {
    _box?.delete(id);
  }

  void toggleTodo(String id) {
    final todo = _box?.get(id);
    if (todo != null) {
      final updatedTodo = todo.copyWith(
        isCompleted: !todo.isCompleted,
        completedAt: !todo.isCompleted ? DateTime.now() : null,
      );
      _box?.put(id, updatedTodo);
    }
  }

  void syncTodos(List<Todo> todos) {
    for (final todo in todos) {
      _box?.put(todo.id, todo);
    }
  }
} 