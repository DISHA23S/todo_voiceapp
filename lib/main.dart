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
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Configure Firestore settings
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Enable offline persistence
  if (!kIsWeb) {  // Only enable persistence on mobile platforms
    await FirebaseFirestore.instance.enablePersistence();
  }
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice To-Do',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF10B981),
          tertiary: const Color(0xFFF43F5E),
          surface: Colors.white,
          background: const Color(0xFFF8FAFC),
          surfaceVariant: const Color(0xFFE2E8F0),
          primaryContainer: const Color(0xFFEEF2FF),
          secondaryContainer: const Color(0xFFECFDF5),
          tertiaryContainer: const Color(0xFFFFE4E6),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          primary: const Color(0xFF818CF8),
          secondary: const Color(0xFF34D399),
          tertiary: const Color(0xFFFB7185),
          surface: const Color(0xFF1E1B4B),
          background: const Color(0xFF0F172A),
          surfaceVariant: const Color(0xFF334155),
          primaryContainer: const Color(0xFF312E81),
          secondaryContainer: const Color(0xFF065F46),
          tertiaryContainer: const Color(0xFF881337),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Voice To-Do',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
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
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Icon(
                              Icons.mic_none_rounded,
                              size: 64,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.primary.withOpacity(0.1),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'No tasks yet',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try saying: "Create task title: Buy groceries"',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                              ],
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
                                icon: Icons.delete_outline_rounded,
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
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    todo.isCompleted
                                        ? colorScheme.secondaryContainer.withOpacity(0.5)
                                        : colorScheme.primaryContainer.withOpacity(0.5),
                                    colorScheme.surface,
                                  ],
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                title: Text(
                                  todo.title,
                                  style: GoogleFonts.inter(
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
                                        style: GoogleFonts.inter(
                                          color: colorScheme.onSurfaceVariant,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isLight
                                            ? colorScheme.surfaceVariant.withOpacity(0.5)
                                            : colorScheme.surfaceVariant.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 14,
                                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            DateFormat('MMM d, y • h:mm a').format(todo.createdAt),
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded),
                                      style: IconButton.styleFrom(
                                        backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
                                      ),
                                      onPressed: () => _showEditDialog(todo),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        todo.isCompleted
                                            ? Icons.check_circle_rounded
                                            : Icons.check_circle_outline_rounded,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: todo.isCompleted
                                            ? colorScheme.secondaryContainer.withOpacity(0.5)
                                            : colorScheme.surfaceVariant.withOpacity(0.5),
                                      ),
                                      color: todo.isCompleted
                                          ? colorScheme.secondary
                                          : colorScheme.onSurfaceVariant,
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_lastWords.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.mic_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _lastWords,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'add',
                        onPressed: _showAddTodoDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Task'),
                        elevation: 0,
                      ),
                      FloatingActionButton(
                        heroTag: 'mic',
                        onPressed: _isListening ? _stopListening : _startListening,
                        backgroundColor: _isListening
                            ? colorScheme.error
                            : colorScheme.primary,
                        elevation: 0,
                        child: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
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

  void _showEditDialog(Todo todo) {
    _titleController.text = todo.title;
    _descriptionController.text = todo.description;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Task',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
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
  }

  Future<void> _showAddTodoDialog() async {
    _titleController.clear();
    _descriptionController.clear();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Task',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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