import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/todo_model.dart';

final todosProvider = StateNotifierProvider<TodoNotifier, List<Todo>>((ref) {
  return TodoNotifier();
});

class TodoNotifier extends StateNotifier<List<Todo>> {
  TodoNotifier() : super([]) {
    _initializeTodos();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box<Todo> _localBox = Hive.box<Todo>('todos');

  Future<void> _initializeTodos() async {
    try {
      // Load from local storage first
      final localTodos = _localBox.values.toList();
      state = localTodos;

      // Then try to sync with Firestore
      final snapshot = await _firestore.collection('todos').get();
      final remoteTodos = snapshot.docs.map((doc) {
        final data = doc.data();
        return Todo.fromJson({...data, 'id': doc.id});
      }).toList();

      // Merge local and remote todos
      final mergedTodos = _mergeTodos(localTodos, remoteTodos);
      state = mergedTodos;

      // Listen for real-time updates
      _firestore.collection('todos').snapshots().listen((snapshot) {
        final remoteTodos = snapshot.docs.map((doc) {
          final data = doc.data();
          return Todo.fromJson({...data, 'id': doc.id});
        }).toList();
        
        state = _mergeTodos(state, remoteTodos);
      });
    } catch (e) {
      print('Error initializing TodoNotifier: $e');
      // If Firestore fails, just use local data
      state = _localBox.values.toList();
    }
  }

  List<Todo> _mergeTodos(List<Todo> local, List<Todo> remote) {
    final Map<String, Todo> merged = {};
    
    // Add all local todos
    for (var todo in local) {
      merged[todo.id] = todo;
    }
    
    // Add/update with remote todos
    for (var todo in remote) {
      final localTodo = merged[todo.id];
      if (localTodo == null || todo.updatedAt.isAfter(localTodo.updatedAt)) {
        merged[todo.id] = todo;
      }
    }
    
    return merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addTodo(Todo todo) async {
    try {
      // Add to Firestore
      final docRef = await _firestore.collection('todos').add(todo.toJson());
      final newTodo = todo.copyWith(title: todo.title);
      
      // Add to local storage
      await _localBox.put(docRef.id, newTodo);
      
      state = [newTodo, ...state];
    } catch (e) {
      print('Error adding todo: $e');
      // If Firestore fails, just add locally
      await _localBox.put(todo.id, todo);
      state = [todo, ...state];
    }
  }

  Future<void> updateTodo(Todo todo) async {
    try {
      // Update in Firestore
      await _firestore.collection('todos').doc(todo.id).update(todo.toJson());
      
      // Update in local storage
      await _localBox.put(todo.id, todo);
      
      state = state.map((t) => t.id == todo.id ? todo : t).toList();
    } catch (e) {
      print('Error updating todo: $e');
      // If Firestore fails, just update locally
      await _localBox.put(todo.id, todo);
      state = state.map((t) => t.id == todo.id ? todo : t).toList();
    }
  }

  Future<void> deleteTodo(String id) async {
    try {
      // Delete from Firestore
      await _firestore.collection('todos').doc(id).delete();
      
      // Delete from local storage
      await _localBox.delete(id);
      
      state = state.where((todo) => todo.id != id).toList();
    } catch (e) {
      print('Error deleting todo: $e');
      // If Firestore fails, just delete locally
      await _localBox.delete(id);
      state = state.where((todo) => todo.id != id).toList();
    }
  }

  Future<void> toggleTodo(String id) async {
    final todo = state.firstWhere((t) => t.id == id);
    final updatedTodo = todo.copyWith(
      isCompleted: !todo.isCompleted,
      updatedAt: DateTime.now(),
    );
    await updateTodo(updatedTodo);
  }
} 