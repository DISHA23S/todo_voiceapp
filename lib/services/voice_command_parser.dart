import '../models/todo_model.dart';

class VoiceCommandParser {
  static Todo? parseCreateCommand(String command) {
    final createPattern = RegExp(r'create|add|new|make', caseSensitive: false);
    if (!createPattern.hasMatch(command)) return null;

    final titlePattern = RegExp(r'title\s*:\s*([^,]+)', caseSensitive: false);
    final descriptionPattern = RegExp(r'description\s*:\s*([^,]+)', caseSensitive: false);

    final titleMatch = titlePattern.firstMatch(command);
    final descriptionMatch = descriptionPattern.firstMatch(command);

    if (titleMatch == null) return null;

    return Todo(
      title: titleMatch.group(1)?.trim() ?? '',
      description: descriptionMatch?.group(1)?.trim() ?? '',
    );
  }

  static String? parseDeleteCommand(String command) {
    final deletePattern = RegExp(r'delete|remove|erase', caseSensitive: false);
    if (!deletePattern.hasMatch(command)) return null;

    final titlePattern = RegExp(r'title\s*:\s*([^,]+)', caseSensitive: false);
    final titleMatch = titlePattern.firstMatch(command);

    return titleMatch?.group(1)?.trim();
  }

  static String? parseCompleteCommand(String command) {
    final completePattern = RegExp(r'complete|finish|done|mark as done', caseSensitive: false);
    if (!completePattern.hasMatch(command)) return null;

    final titlePattern = RegExp(r'title\s*:\s*([^,]+)', caseSensitive: false);
    final titleMatch = titlePattern.firstMatch(command);

    return titleMatch?.group(1)?.trim();
  }

  static (String?, String?, String?)? parseUpdateCommand(String command) {
    final updatePattern = RegExp(r'update|modify|change|edit', caseSensitive: false);
    if (!updatePattern.hasMatch(command)) return null;

    final oldTitlePattern = RegExp(r'old title\s*:\s*([^,]+)', caseSensitive: false);
    final newTitlePattern = RegExp(r'new title\s*:\s*([^,]+)', caseSensitive: false);
    final newDescriptionPattern = RegExp(r'new description\s*:\s*([^,]+)', caseSensitive: false);

    final oldTitleMatch = oldTitlePattern.firstMatch(command);
    final newTitleMatch = newTitlePattern.firstMatch(command);
    final newDescriptionMatch = newDescriptionPattern.firstMatch(command);

    if (oldTitleMatch == null) return null;

    return (
      oldTitleMatch.group(1)?.trim(),
      newTitleMatch?.group(1)?.trim(),
      newDescriptionMatch?.group(1)?.trim(),
    );
  }
} 