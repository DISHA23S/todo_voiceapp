# Voice-Driven To-Do List App

A Flutter-based voice-driven to-do list application that allows users to manage their tasks entirely through voice commands. The app supports offline voice capture and automatic synchronization with a cloud backend when connectivity is restored.

## Features

- 🎤 Voice command support for creating, updating, and managing tasks
- 📱 Modern Material Design 3 UI
- 💾 Offline support with local storage
- 🔄 Real-time sync across devices
- 🔊 Voice feedback for actions
- 🎯 Natural language processing for voice commands

## Voice Commands

The app understands the following voice commands:

### Create a Task
- "Create task title: [task name] description: [task description]"
- "Add task title: [task name]"
- "New task title: [task name] description: [task description]"

### Update a Task
- "Update task old title: [current title] new title: [new title]"
- "Modify task old title: [current title] new description: [new description]"
- "Change task old title: [current title] new title: [new title] new description: [new description]"

### Complete a Task
- "Complete task title: [task name]"
- "Mark as done title: [task name]"
- "Finish task title: [task name]"

### Delete a Task
- "Delete task title: [task name]"
- "Remove task title: [task name]"
- "Erase task title: [task name]"

## Getting Started

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Dependencies

- flutter_riverpod: State management
- speech_to_text: Voice recognition
- flutter_tts: Text-to-speech feedback
- hive: Local storage
- firebase_core & cloud_firestore: Cloud sync
- flutter_slidable: Task swipe actions
- intl: Date formatting
- google_fonts: Typography

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
