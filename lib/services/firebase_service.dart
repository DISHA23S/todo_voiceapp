import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/todo_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'todos';

  Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  Stream<List<Todo>> getTodosStream() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Todo.fromJson(doc.data()))
            .toList());
  }

  Future<void> addTodo(Todo todo) async {
    await _firestore.collection(_collection).doc(todo.id).set(todo.toJson());
  }

  Future<void> updateTodo(Todo todo) async {
    await _firestore.collection(_collection).doc(todo.id).update(todo.toJson());
  }

  Future<void> deleteTodo(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<void> syncTodos(List<Todo> todos) async {
    final batch = _firestore.batch();
    for (final todo in todos) {
      batch.set(_firestore.collection(_collection).doc(todo.id), todo.toJson());
    }
    await batch.commit();
  }
} 