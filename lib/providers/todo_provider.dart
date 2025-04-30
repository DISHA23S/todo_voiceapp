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

final todosProvider = StateNotifierProvider<TodosNotifier, List<Todo>>((ref) {
  final box = ref.watch(todoBoxProvider).value;
  final firebaseService = ref.watch(firebaseServiceProvider);
  return TodosNotifier(box, firebaseService);
});

class TodosNotifier extends StateNotifier<List<Todo>> {
  final Box<Todo>? _box;
  final FirebaseService _firebaseService;
  bool _isInitialized = false;

  TodosNotifier(this._box, this._firebaseService) : super(_box?.values.toList() ?? []) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    // Listen to Firebase changes
    _firebaseService.getTodosStream().listen((firebaseTodos) {
      if (_box != null) {
        // Update local storage with Firebase data
        for (final todo in firebaseTodos) {
          _box!.put(todo.id, todo);
        }
        state = _box!.values.toList();
      }
    });

    // Sync local changes to Firebase
    _box?.watch().listen((event) {
      if (event.deleted) {
        _firebaseService.deleteTodo(event.key as String);
      } else {
        final todo = event.value as Todo;
        if (!todo.isSynced) {
          _firebaseService.updateTodo(todo.copyWith(isSynced: true));
        }
      }
    });

    _isInitialized = true;
  }

  void addTodo(Todo todo) {
    _box?.put(todo.id, todo);
    _firebaseService.addTodo(todo);
  }

  void updateTodo(Todo todo) {
    _box?.put(todo.id, todo);
    _firebaseService.updateTodo(todo);
  }

  void deleteTodo(String id) {
    _box?.delete(id);
    _firebaseService.deleteTodo(id);
  }

  void toggleTodo(String id) {
    final todo = _box?.get(id);
    if (todo != null) {
      final updatedTodo = todo.copyWith(
        isCompleted: !todo.isCompleted,
        completedAt: !todo.isCompleted ? DateTime.now() : null,
      );
      _box?.put(id, updatedTodo);
      _firebaseService.updateTodo(updatedTodo);
    }
  }

  Future<void> syncTodos(List<Todo> todos) async {
    if (_box != null) {
      for (final todo in todos) {
        _box!.put(todo.id, todo);
      }
      state = _box!.values.toList();
    }
    await _firebaseService.syncTodos(todos);
  }
} 