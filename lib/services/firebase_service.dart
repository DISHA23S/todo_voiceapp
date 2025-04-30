import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import '../models/todo_model.dart';
import 'queue_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'todos';
  final QueueService _queueService = QueueService();
  bool _isOnline = true;
  Timer? _syncTimer;

  Future<void> initialize() async {
    await Firebase.initializeApp();
    await _queueService.initialize();
    
    // Enable offline persistence
    await _firestore.enablePersistence();
    
    // Start periodic sync check
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) => _syncQueuedCommands());
    
    // Listen to connectivity changes
    _firestore.waitForPendingWrites().then((_) {
      _isOnline = true;
      _syncQueuedCommands();
    }).catchError((_) {
      _isOnline = false;
    });
  }

  Stream<List<Todo>> getTodosStream() {
    return _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Todo.fromJson(doc.data()))
            .toList());
  }

  Future<void> addTodo(Todo todo) async {
    try {
      await _firestore.collection(_collection).doc(todo.id).set(
        todo.toJson(),
        SetOptions(merge: true),
      );
    } catch (e) {
      // Store in offline queue if operation fails
      await _queueService.addCommand(
        QueuedCommand(type: CommandType.create, todo: todo),
      );
    }
  }

  Future<void> updateTodo(Todo todo) async {
    try {
      final docRef = _firestore.collection(_collection).doc(todo.id);
      
      // Get the current version from Firestore
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final currentTodo = Todo.fromJson(docSnapshot.data()!);
        
        // Check if the todo has been modified since last fetch
        if (currentTodo.updatedAt.isAfter(todo.updatedAt)) {
          // Conflict detected - merge changes
          final mergedTodo = _mergeTodoChanges(currentTodo, todo);
          await docRef.update(mergedTodo.toJson());
        } else {
          // No conflict - update normally
          await docRef.update(todo.toJson());
        }
      } else {
        // Document doesn't exist - create it
        await docRef.set(todo.toJson());
      }
    } catch (e) {
      // Store in offline queue if operation fails
      await _queueService.addCommand(
        QueuedCommand(type: CommandType.update, todo: todo),
      );
    }
  }

  Future<void> deleteTodo(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      // Store in offline queue if operation fails
      final todo = Todo(id: id, title: '', description: '');
      await _queueService.addCommand(
        QueuedCommand(type: CommandType.delete, todo: todo),
      );
    }
  }

  Future<void> toggleTodo(String id) async {
    try {
      final docRef = _firestore.collection(_collection).doc(id);
      final doc = await docRef.get();
      if (doc.exists) {
        final todo = Todo.fromJson(doc.data()!);
        final updatedTodo = todo.copyWith(isCompleted: !todo.isCompleted);
        await docRef.update(updatedTodo.toJson());
      }
    } catch (e) {
      // Store in offline queue if operation fails
      final todo = Todo(id: id, title: '', description: '');
      await _queueService.addCommand(
        QueuedCommand(type: CommandType.complete, todo: todo),
      );
    }
  }

  Todo _mergeTodoChanges(Todo current, Todo update) {
    return Todo(
      id: current.id,
      title: update.title,
      description: update.description,
      isCompleted: update.isCompleted,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _syncQueuedCommands() async {
    if (!_isOnline) return;

    final commands = _queueService.getQueuedCommands();
    for (var i = 0; i < commands.length; i++) {
      final command = commands[i];
      try {
        switch (command.type) {
          case CommandType.create:
            await _firestore
                .collection(_collection)
                .doc(command.todo.id)
                .set(command.todo.toJson());
            break;
          case CommandType.update:
            await updateTodo(command.todo);
            break;
          case CommandType.delete:
            await _firestore
                .collection(_collection)
                .doc(command.todo.id)
                .delete();
            break;
          case CommandType.complete:
            await toggleTodo(command.todo.id);
            break;
        }
        await _queueService.removeCommand(i);
      } catch (_) {
        // If sync fails, keep the command in the queue
        continue;
      }
    }
  }

  void dispose() {
    _syncTimer?.cancel();
  }
} 