// import 'dart:io' show Platform;
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:window_manager/window_manager.dart';

// // Your new implementation bridging UI, the Delegate, and the Notifier
// class ProjectMenuHandler implements DawMenuDelegate {
//   final WidgetRef ref;
//   final String? projectId; // Example: Pass an ID if using Provider.family

//   ProjectMenuHandler(this.ref, {this.projectId});

//   Future<void> _updateWindowTitle(String filePath) async {
//     if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
//       final fileName = filePath.split(RegExp(r'[/\\]')).last;
//       try {
//         await windowManager.setTitle('DigiDAW — $fileName');
//       } catch (e) {
//         debugPrint("Failed to set window title: $e");
//       }
//     }
//   }

//   @override
//   void onSaveAs(BuildContext context) async {
//     // 1. UI Logic (File Picker)
//     final path = await FilePicker.saveFile(
//       dialogTitle: 'Save Project As...',
//       fileName: 'untitled.dgdaw',
//       type: FileType.custom,
//       allowedExtensions: ['karbeat', 'dgdaw'],
//     );

//     if (path != null) {
//       if (context.mounted) {
//         // 2. UI Logic (Loading Dialog)
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (context) => const Center(child: CircularProgressIndicator()),
//         );
//       }

//       // 3. Business Logic (Notifier)
//       // If using a family: ref.read(projectProvider(projectId!).notifier).saveProject(path);
//       await ref.read(projectProvider.notifier).saveProject(path);
//       await _updateWindowTitle(path);

//       if (context.mounted) Navigator.of(context).pop();
//     }
//   }

//   @override
//   void onNewProject(BuildContext context) {
//     ref.read(projectProvider.notifier).newBlankProject();
//     _updateWindowTitle('Untitled');
//   }

//   @override
//   void onOpenProject(BuildContext context) async {
//     // Implement your file picker and loading dialog here...
//   }

//   @override
//   void onSaveProject(BuildContext context) {
//     // Implement your silent save or fallback to onSaveAs here...
//   }

//   @override
//   void onExportProject(BuildContext context) {
//     ref.read(uiStateProvider.notifier).openExportPanel();
//   }

//   // ... Implement remaining interface methods (Undo, Zoom, etc.)
//   @override void onImportAudio(BuildContext context) {}
//   @override void onOpenSettings(BuildContext context) {}
//   @override void onUndo(BuildContext context) {}
//   @override void onRedo(BuildContext context) {}
//   @override void onZoomIn(BuildContext context) {}
//   @override void onZoomOut(BuildContext context) {}
// }