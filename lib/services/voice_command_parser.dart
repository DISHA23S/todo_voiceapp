import '../models/todo_model.dart';

class VoiceCommandParser {
  static Todo? parseCreateCommand(String command) {
    final createPattern = RegExp(r'create|add|new|make|add task|create task', caseSensitive: false);
    if (!createPattern.hasMatch(command)) return null;

    final titlePattern = RegExp(r'title\s*:\s*([^,]+)|task\s*:\s*([^,]+)|about\s*:\s*([^,]+)', caseSensitive: false);
    final descriptionPattern = RegExp(r'description\s*:\s*([^,]+)|details\s*:\s*([^,]+)|note\s*:\s*([^,]+)', caseSensitive: false);

    final titleMatch = titlePattern.firstMatch(command);
    final descriptionMatch = descriptionPattern.firstMatch(command);

    String? title;
    if (titleMatch != null) {
      title = titleMatch.group(1) ?? titleMatch.group(2) ?? titleMatch.group(3);
    } else {
      final words = command.split(' ');
      final createIndex = words.indexWhere((word) => createPattern.hasMatch(word));
      if (createIndex != -1 && createIndex + 1 < words.length) {
        title = words.sublist(createIndex + 1).join(' ');
      }
    }

    if (title == null || title.isEmpty) return null;

    String? description;
    if (descriptionMatch != null) {
      description = descriptionMatch.group(1) ?? descriptionMatch.group(2) ?? descriptionMatch.group(3);
    }

    return Todo(
      title: title.trim(),
      description: description?.trim() ?? '',
    );
  }

  static String? parseDeleteCommand(String command) {
    final deletePattern = RegExp(r'delete|remove|erase|remove task|delete task', caseSensitive: false);
    if (!deletePattern.hasMatch(command)) return null;

    final titlePattern = RegExp(r'title\s*:\s*([^,]+)|task\s*:\s*([^,]+)|about\s*:\s*([^,]+)', caseSensitive: false);
    final titleMatch = titlePattern.firstMatch(command);

    if (titleMatch != null) {
      return titleMatch.group(1) ?? titleMatch.group(2) ?? titleMatch.group(3);
    }

    final words = command.split(' ');
    final deleteIndex = words.indexWhere((word) => deletePattern.hasMatch(word));
    if (deleteIndex != -1 && deleteIndex + 1 < words.length) {
      return words.sublist(deleteIndex + 1).join(' ');
    }

    return null;
  }

  static String? parseCompleteCommand(String command) {
    final completePattern = RegExp(r'complete|finish|done|mark as done|complete task|finish task', caseSensitive: false);
    if (!completePattern.hasMatch(command)) return null;

    final titlePattern = RegExp(r'title\s*:\s*([^,]+)|task\s*:\s*([^,]+)|about\s*:\s*([^,]+)', caseSensitive: false);
    final titleMatch = titlePattern.firstMatch(command);

    if (titleMatch != null) {
      return titleMatch.group(1) ?? titleMatch.group(2) ?? titleMatch.group(3);
    }

    final words = command.split(' ');
    final completeIndex = words.indexWhere((word) => completePattern.hasMatch(word));
    if (completeIndex != -1 && completeIndex + 1 < words.length) {
      return words.sublist(completeIndex + 1).join(' ');
    }

    return null;
  }

  static (String?, String?, String?)? parseUpdateCommand(String command) {
    final updatePattern = RegExp(r'update|modify|change|edit|update task|modify task', caseSensitive: false);
    if (!updatePattern.hasMatch(command)) return null;

    final oldTitlePattern = RegExp(r'old title\s*:\s*([^,]+)|current task\s*:\s*([^,]+)', caseSensitive: false);
    final newTitlePattern = RegExp(r'new title\s*:\s*([^,]+)|updated task\s*:\s*([^,]+)', caseSensitive: false);
    final newDescriptionPattern = RegExp(r'new description\s*:\s*([^,]+)|updated details\s*:\s*([^,]+)', caseSensitive: false);

    final oldTitleMatch = oldTitlePattern.firstMatch(command);
    final newTitleMatch = newTitlePattern.firstMatch(command);
    final newDescriptionMatch = newDescriptionPattern.firstMatch(command);

    String? oldTitle;
    if (oldTitleMatch != null) {
      oldTitle = oldTitleMatch.group(1) ?? oldTitleMatch.group(2);
    } else {
      final words = command.split(' ');
      final updateIndex = words.indexWhere((word) => updatePattern.hasMatch(word));
      if (updateIndex != -1 && updateIndex + 1 < words.length) {
        oldTitle = words.sublist(updateIndex + 1).join(' ');
      }
    }

    if (oldTitle == null || oldTitle.isEmpty) return null;

    String? newTitle;
    if (newTitleMatch != null) {
      newTitle = newTitleMatch.group(1) ?? newTitleMatch.group(2);
    }

    String? newDescription;
    if (newDescriptionMatch != null) {
      newDescription = newDescriptionMatch.group(1) ?? newDescriptionMatch.group(2);
    }

    return (oldTitle.trim(), newTitle?.trim(), newDescription?.trim());
  }
} 