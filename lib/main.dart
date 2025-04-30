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
import 'services/voice_feedback_service.dart';
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
          seedColor: const Color(0xFF7C4DFF), // Deep purple accent
          brightness: Brightness.light,
          primary: const Color(0xFF7C4DFF),
          secondary: const Color(0xFF00BFA5), // Teal accent
          tertiary: const Color(0xFFFF4081), // Pink accent
          surface: Colors.white,
          background: const Color(0xFFF8F9FA),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
          primary: const Color(0xFF7C4DFF),
          secondary: const Color(0xFF00BFA5),
          tertiary: const Color(0xFFFF4081),
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
  final VoiceFeedbackService _voiceFeedback = VoiceFeedbackService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isListening = false;
  String _lastWords = '';
  bool _isProcessing = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _speechToText.initialize();
    await _voiceFeedback.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _voiceFeedback.dispose();
    super.dispose();
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

    try {
      // Try to parse the command
      final todo = VoiceCommandParser.parseCreateCommand(_lastWords);
      if (todo != null) {
        ref.read(todosProvider.notifier).addTodo(todo);
        await _voiceFeedback.confirmTaskCreation(todo.title);
        if (_isOffline) {
          await _voiceFeedback.notifyOffline();
        }
        setState(() => _lastWords = '');
        return;
      }

      final deleteTitle = VoiceCommandParser.parseDeleteCommand(_lastWords);
      if (deleteTitle != null) {
        final todos = ref.read(todosProvider);
        final todo = todos.firstWhere(
          (t) => t.title.toLowerCase().contains(deleteTitle.toLowerCase()),
          orElse: () => Todo(title: '', description: ''),
        );
        if (todo.id.isNotEmpty) {
          ref.read(todosProvider.notifier).deleteTodo(todo.id);
          await _voiceFeedback.confirmTaskDeletion(todo.title);
          if (_isOffline) {
            await _voiceFeedback.notifyOffline();
          }
        } else {
          await _voiceFeedback.notifyError('Task not found: $deleteTitle');
        }
        setState(() => _lastWords = '');
        return;
      }

      final completeTitle = VoiceCommandParser.parseCompleteCommand(_lastWords);
      if (completeTitle != null) {
        final todos = ref.read(todosProvider);
        final todo = todos.firstWhere(
          (t) => t.title.toLowerCase().contains(completeTitle.toLowerCase()),
          orElse: () => Todo(title: '', description: ''),
        );
        if (todo.id.isNotEmpty) {
          ref.read(todosProvider.notifier).toggleTodo(todo.id);
          await _voiceFeedback.confirmTaskCompletion(todo.title, !todo.isCompleted);
          if (_isOffline) {
            await _voiceFeedback.notifyOffline();
          }
        } else {
          await _voiceFeedback.notifyError('Task not found: $completeTitle');
        }
        setState(() => _lastWords = '');
        return;
      }

      final updateCommand = VoiceCommandParser.parseUpdateCommand(_lastWords);
      if (updateCommand != null) {
        final (oldTitle, newTitle, newDescription) = updateCommand;
        if (oldTitle == null) {
          await _voiceFeedback.notifyError('Could not understand which task to update');
          setState(() => _lastWords = '');
          return;
        }

        final todos = ref.read(todosProvider);
        final todo = todos.firstWhere(
          (t) => t.title.toLowerCase().contains(oldTitle.toLowerCase()),
          orElse: () => Todo(title: '', description: ''),
        );

        if (todo.id.isNotEmpty) {
          if (newTitle == null && newDescription == null) {
            await _voiceFeedback.notifyError('Please specify new title or description');
            return;
          }

          final updatedTodo = todo.copyWith(
            title: newTitle ?? todo.title,
            description: newDescription ?? todo.description,
            updatedAt: DateTime.now(),
          );

          ref.read(todosProvider.notifier).updateTodo(updatedTodo);
          await _voiceFeedback.confirmTaskUpdate(updatedTodo.title);
          
          // Provide detailed feedback about what was updated
          if (newTitle != null && newDescription != null) {
            await _voiceFeedback.speak('Updated title and description');
          } else if (newTitle != null) {
            await _voiceFeedback.speak('Updated title to: $newTitle');
          } else if (newDescription != null) {
            await _voiceFeedback.speak('Updated description to: $newDescription');
          }

          if (_isOffline) {
            await _voiceFeedback.notifyOffline();
          }
        } else {
          await _voiceFeedback.notifyError('Task not found: $oldTitle');
        }
        setState(() => _lastWords = '');
        return;
      }

      // If no command was recognized
      await _voiceFeedback.speak('I heard: $_lastWords');
      await _voiceFeedback.requestClarification();
      await _voiceFeedback.speak('Try saying: "update task [old title] to [new title]" or "change task [name] with [new description]"');
    } catch (e) {
      await _voiceFeedback.notifyError('An error occurred while processing your command');
    } finally {
      setState(() {
        _lastWords = '';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Voice To-Do',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              // TODO: Implement sync functionality
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.background,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: todos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mic_none,
                            size: 80,
                            color: colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'No tasks yet\nTry saying: "Create task title: Buy groceries"',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.8),
                                    height: 1.5,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: todos.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                backgroundColor: colorScheme.errorContainer,
                                foregroundColor: colorScheme.onErrorContainer,
                                icon: Icons.delete_outline,
                                label: 'Delete',
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ],
                          ),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: todo.isCompleted ? colorScheme.secondary : colorScheme.primary,
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Text(
                                  todo.title,
                                  style: TextStyle(
                                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: todo.isCompleted 
                                        ? colorScheme.onSurface.withOpacity(0.6)
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (todo.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        todo.description,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('MMM d, y • h:mm a').format(todo.createdAt),
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () {
                                        _titleController.text = todo.title;
                                        _descriptionController.text = todo.description;
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Edit Task'),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextField(
                                                  controller: _titleController,
                                                  decoration: InputDecoration(
                                                    labelText: 'Title',
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller: _descriptionController,
                                                  decoration: InputDecoration(
                                                    labelText: 'Description',
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                  maxLines: 3,
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(color: colorScheme.secondary),
                                                ),
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
                                                style: FilledButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        todo.isCompleted 
                                            ? Icons.check_circle
                                            : Icons.check_circle_outline,
                                        color: todo.isCompleted
                                            ? colorScheme.secondary
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        ref.read(todosProvider.notifier).toggleTodo(todo.id);
                                      },
                                    ),
                                  ],
                                ),
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
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_lastWords.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mic,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _lastWords,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'add',
                        onPressed: _showAddTodoDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Task'),
                      ),
                      FloatingActionButton(
                        heroTag: 'mic',
                        onPressed: _isListening ? _stopListening : _startListening,
                        backgroundColor: _isListening
                            ? colorScheme.error
                            : colorScheme.primary,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTodoDialog() async {
    _titleController.clear();
    _descriptionController.clear();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Enter task title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Enter task description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
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
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}