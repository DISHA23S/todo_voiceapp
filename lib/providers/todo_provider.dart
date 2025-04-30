import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/todo_model.dart';
import '../services/firebase_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final todoBoxProvider = FutureProvider<Box<Todo>>((ref) async {
  return Hive.box<Todo>('todos');
});

final todosProvider = StateNotifierProvider<TodoNotifier, List<Todo>>((ref) {
  return TodoNotifier();
});

class TodoNotifier extends StateNotifier<List<Todo>> {
  TodoNotifier() : super([]) {
    _initialize();
  }

  final _todoBox = Hive.box<Todo>('todos');
  final _firebaseService = FirebaseService();

  Future<void> _initialize() async {
    await _firebaseService.initialize();
    
    // Load local todos
    final localTodos = _todoBox.values.toList();
    state = localTodos;

    // Listen to Firebase changes
    _firebaseService.getTodosStream().listen((remoteTodos) {
      _handleRemoteTodos(remoteTodos);
    });
  }

  void _handleRemoteTodos(List<Todo> remoteTodos) {
    final localTodos = List<Todo>.from(state);
    final updatedTodos = <Todo>[];

    // Merge remote and local todos
    for (final remoteTodo in remoteTodos) {
      final localIndex = localTodos.indexWhere((t) => t.id == remoteTodo.id);
      if (localIndex >= 0) {
        final localTodo = localTodos[localIndex];
        // Keep the most recently updated version
        if (remoteTodo.updatedAt.isAfter(localTodo.updatedAt)) {
          updatedTodos.add(remoteTodo);
        } else {
          updatedTodos.add(localTodo);
        }
      } else {
        updatedTodos.add(remoteTodo);
      }
    }

    // Add local todos that don't exist in remote
    for (final localTodo in localTodos) {
      if (!remoteTodos.any((t) => t.id == localTodo.id)) {
        updatedTodos.add(localTodo);
      }
    }

    // Update state and local storage
    state = updatedTodos;
    _saveToLocal(updatedTodos);
  }

  Future<void> _saveToLocal(List<Todo> todos) async {
    await _todoBox.clear();
    await _todoBox.addAll(todos);
  }

  Future<void> addTodo(Todo todo) async {
    state = [...state, todo];
    await _todoBox.add(todo);
    await _firebaseService.addTodo(todo);
  }

  Future<void> updateTodo(Todo todo) async {
    state = [
      for (final t in state)
        if (t.id == todo.id) todo else t
    ];
    
    final index = _todoBox.values.toList().indexWhere((t) => t.id == todo.id);
    if (index >= 0) {
      await _todoBox.putAt(index, todo);
    }
    
    await _firebaseService.updateTodo(todo);
  }

  Future<void> deleteTodo(String id) async {
    state = state.where((t) => t.id != id).toList();
    
    final index = _todoBox.values.toList().indexWhere((t) => t.id == id);
    if (index >= 0) {
      await _todoBox.deleteAt(index);
    }
    
    await _firebaseService.deleteTodo(id);
  }

  Future<void> toggleTodo(String id) async {
    state = [
      for (final todo in state)
        if (todo.id == id)
          todo.copyWith(
            isCompleted: !todo.isCompleted,
            updatedAt: DateTime.now(),
          )
        else
          todo
    ];
    
    final index = _todoBox.values.toList().indexWhere((t) => t.id == id);
    if (index >= 0) {
      final todo = _todoBox.getAt(index)!;
      await _todoBox.putAt(
        index,
        todo.copyWith(
          isCompleted: !todo.isCompleted,
          updatedAt: DateTime.now(),
        ),
      );
    }
    
    await _firebaseService.toggleTodo(id);
  }
} 