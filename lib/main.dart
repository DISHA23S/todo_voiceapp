import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'models/todo_model.dart';
import 'providers/todo_provider.dart';
import 'services/voice_command_parser.dart';
import 'services/firebase_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TodoAdapter());
  await Hive.openBox<Todo>('todos');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice To-Do',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isListening = false;
  String _lastWords = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  void _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
        });
      },
    );
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
    _processCommand();
  }

  Future<void> _processCommand() async {
    if (_lastWords.isEmpty) return;

    setState(() => _isProcessing = true);

    // Try to parse the command
    final todo = VoiceCommandParser.parseCreateCommand(_lastWords);
    if (todo != null) {
      ref.read(todosProvider.notifier).addTodo(todo);
      await _flutterTts.speak('Task added: ${todo.title}');
      setState(() => _lastWords = '');
      return;
    }

    final deleteTitle = VoiceCommandParser.parseDeleteCommand(_lastWords);
    if (deleteTitle != null) {
      final todos = ref.read(todosProvider);
      final todo = todos.firstWhere(
        (t) => t.title.toLowerCase() == deleteTitle.toLowerCase(),
        orElse: () => Todo(title: '', description: ''),
      );
      if (todo.id.isNotEmpty) {
        ref.read(todosProvider.notifier).deleteTodo(todo.id);
        await _flutterTts.speak('Task deleted: ${todo.title}');
      } else {
        await _flutterTts.speak('Task not found');
      }
      setState(() => _lastWords = '');
      return;
    }

    final completeTitle = VoiceCommandParser.parseCompleteCommand(_lastWords);
    if (completeTitle != null) {
      final todos = ref.read(todosProvider);
      final todo = todos.firstWhere(
        (t) => t.title.toLowerCase() == completeTitle.toLowerCase(),
        orElse: () => Todo(title: '', description: ''),
      );
      if (todo.id.isNotEmpty) {
        ref.read(todosProvider.notifier).toggleTodo(todo.id);
        await _flutterTts.speak('Task marked as completed: ${todo.title}');
      } else {
        await _flutterTts.speak('Task not found');
      }
      setState(() => _lastWords = '');
      return;
    }

    final updateCommand = VoiceCommandParser.parseUpdateCommand(_lastWords);
    if (updateCommand != null) {
      final (oldTitle, newTitle, newDescription) = updateCommand;
      final todos = ref.read(todosProvider);
      final todo = todos.firstWhere(
        (t) => t.title.toLowerCase() == oldTitle?.toLowerCase(),
        orElse: () => Todo(title: '', description: ''),
      );
      if (todo.id.isNotEmpty) {
        final updatedTodo = todo.copyWith(
          title: newTitle ?? todo.title,
          description: newDescription ?? todo.description,
        );
        ref.read(todosProvider.notifier).updateTodo(updatedTodo);
        await _flutterTts.speak('Task updated: ${updatedTodo.title}');
      } else {
        await _flutterTts.speak('Task not found');
      }
      setState(() => _lastWords = '');
      return;
    }

    await _flutterTts.speak('I could not understand that command. Please try again.');
    setState(() => _lastWords = '');
  }

  Future<void> _showAddTodoDialog() async {
    _titleController.clear();
    _descriptionController.clear();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter task title',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter task description (optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty) {
                final todo = Todo(
                  title: _titleController.text,
                  description: _descriptionController.text,
                );
                ref.read(todosProvider.notifier).addTodo(todo);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice To-Do'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              // TODO: Implement sync functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: todos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_none,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks yet\nTry saying: "Create task title: Buy groceries"',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: todos.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return Slidable(
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) {
                                ref.read(todosProvider.notifier).deleteTodo(todo.id);
                              },
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: 'Delete',
                            ),
                          ],
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(
                              todo.title,
                              style: TextStyle(
                                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (todo.description.isNotEmpty)
                                  Text(todo.description),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, y • h:mm a').format(todo.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    _titleController.text = todo.title;
                                    _descriptionController.text = todo.description;
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Edit Task'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: _titleController,
                                              decoration: const InputDecoration(
                                                labelText: 'Title',
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextField(
                                              controller: _descriptionController,
                                              decoration: const InputDecoration(
                                                labelText: 'Description',
                                              ),
                                              maxLines: 3,
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              if (_titleController.text.isNotEmpty) {
                                                final updatedTodo = todo.copyWith(
                                                  title: _titleController.text,
                                                  description: _descriptionController.text,
                                                );
                                                ref.read(todosProvider.notifier).updateTodo(updatedTodo);
                                                Navigator.pop(context);
                                              }
                                            },
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    todo.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                                    color: todo.isCompleted
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                  onPressed: () {
                                    ref.read(todosProvider.notifier).toggleTodo(todo.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_lastWords.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mic,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastWords,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      heroTag: 'add',
                      onPressed: _showAddTodoDialog,
                      child: const Icon(Icons.add),
                    ),
                    FloatingActionButton(
                      heroTag: 'mic',
                      onPressed: _isListening ? _stopListening : _startListening,
                      backgroundColor: _isListening
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
