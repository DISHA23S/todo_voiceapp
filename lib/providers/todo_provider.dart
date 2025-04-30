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
  bool _isInitialized = false;

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize Firebase service
      await _firebaseService.initialize();
      
      // Load local todos first
      final localTodos = _todoBox.values.toList();
      state = localTodos;
      
      // Listen to Firebase changes
      _firebaseService.getTodosStream().listen((remoteTodos) {
        _handleRemoteTodos(remoteTodos);
      });

      // Initial fetch from Firebase
      final initialRemoteTodos = await _firebaseService.fetchInitialTodos();
      if (initialRemoteTodos.isNotEmpty) {
        _handleRemoteTodos(initialRemoteTodos);
      }

      _isInitialized = true;
    } catch (e) {
      print('Error initializing TodoNotifier: $e');
      // If Firebase fails, still show local todos
      state = _todoBox.values.toList();
    }
  }

  void _handleRemoteTodos(List<Todo> remoteTodos) {
    final localTodos = List<Todo>.from(state);
    final updatedTodos = <Todo>[];
    final Map<String, Todo> todoMap = {};

    // First, add all remote todos to the map
    for (final todo in remoteTodos) {
      todoMap[todo.id] = todo;
    }

    // Then, add local todos that are not in remote or are more recent
    for (final localTodo in localTodos) {
      final remoteTodo = todoMap[localTodo.id];
      if (remoteTodo == null || localTodo.updatedAt.isAfter(remoteTodo.updatedAt)) {
        todoMap[localTodo.id] = localTodo;
      }
    }

    // Convert map back to list and sort by creation date
    updatedTodos.addAll(todoMap.values);
    updatedTodos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Update state and local storage
    state = updatedTodos;
    _saveToLocal(updatedTodos);
  }

  Future<void> _saveToLocal(List<Todo> todos) async {
    await _todoBox.clear();
    for (final todo in todos) {
      await _todoBox.put(todo.id, todo);
    }
  }

  Future<void> addTodo(Todo todo) async {
    state = [...state, todo];
    await _todoBox.put(todo.id, todo);
    try {
      await _firebaseService.addTodo(todo);
    } catch (e) {
      print('Error adding todo to Firebase: $e');
    }
  }

  Future<void> updateTodo(Todo todo) async {
    state = [
      for (final t in state)
        if (t.id == todo.id) todo else t
    ];
    
    await _todoBox.put(todo.id, todo);
    try {
      await _firebaseService.updateTodo(todo);
    } catch (e) {
      print('Error updating todo in Firebase: $e');
    }
  }

  Future<void> deleteTodo(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _todoBox.delete(id);
    try {
      await _firebaseService.deleteTodo(id);
    } catch (e) {
      print('Error deleting todo from Firebase: $e');
    }
  }

  Future<void> toggleTodo(String id) async {
    final todoIndex = state.indexWhere((t) => t.id == id);
    if (todoIndex == -1) return;

    final todo = state[todoIndex];
    final updatedTodo = todo.copyWith(
      isCompleted: !todo.isCompleted,
      updatedAt: DateTime.now(),
    );

    state = [
      for (final t in state)
        if (t.id == id) updatedTodo else t
    ];
    
    await _todoBox.put(id, updatedTodo);
    try {
      await _firebaseService.toggleTodo(id);
    } catch (e) {
      print('Error toggling todo in Firebase: $e');
    }
  }

  Future<void> refreshTodos() async {
    try {
      final remoteTodos = await _firebaseService.fetchInitialTodos();
      _handleRemoteTodos(remoteTodos);
    } catch (e) {
      print('Error refreshing todos: $e');
    }
  }
} 