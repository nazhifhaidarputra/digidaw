enum ToolSelection { pointer, slice, draw, move, delete, zoom, select, resize }

/// Piano roll specific tool selection (independent from main toolbar)
enum PianoRollToolSelection { grab, draw, delete, select, slice, pan, zoom }

enum WorkspaceView { trackList, pianoRoll, mixer, source }

enum ToolbarMenuContextGroup { none, project, edit, view }

/// Events that trigger a state refresh
enum ProjectEvent {
  tracksChanged,
  transportChanged,
  metadataChanged,
  sourceListChanged,
  generatorListChanged,
  effectListChanged,
  configChanged,
  patternChanged,
  mixerChanged,
}