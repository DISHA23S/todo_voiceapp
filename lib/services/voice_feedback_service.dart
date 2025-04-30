import 'package:flutter_tts/flutter_tts.dart';

class VoiceFeedbackService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  Future<void> initialize() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  Future<void> speak(String message) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    _isSpeaking = true;
    await _flutterTts.speak(message);
  }

  Future<void> confirmTaskCreation(String title) async {
    await speak('Task added: $title');
  }

  Future<void> confirmTaskDeletion(String title) async {
    await speak('Task deleted: $title');
  }

  Future<void> confirmTaskCompletion(String title, bool isCompleted) async {
    if (isCompleted) {
      await speak('Task completed: $title');
    } else {
      await speak('Task marked as incomplete: $title');
    }
  }

  Future<void> confirmTaskUpdate(String title) async {
    await speak('Task updated: $title');
  }

  Future<void> notifyError(String message) async {
    await speak('Error: $message');
  }

  Future<void> requestClarification() async {
    await speak('I could not understand that command. Please try again.');
  }

  Future<void> notifyOffline() async {
    await speak('You are currently offline. Your changes will be synced when you reconnect.');
  }

  Future<void> notifySyncing() async {
    await speak('Syncing your changes...');
  }

  Future<void> notifySyncComplete() async {
    await speak('All changes have been synced.');
  }

  Future<void> dispose() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
  }
} 