class ProjectState {
  
  /// Path of the currently open project file.  `null` when unsaved.
  final String? currentFilePath;

  ProjectState({
    required this.currentFilePath,
  });

  
}
