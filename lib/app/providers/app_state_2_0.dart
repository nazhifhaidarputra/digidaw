import 'package:karbeat/features/piano_roll/view/floating_midi_keyboard.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/shared/models/interaction_target.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/shared/enums/global.dart';

class GlobalAppStateData {
  // ================ TRANSPORT STATE ============================
  final UiTransportState transportState = transportStateNew();
  final bool isLooping = false;
  final bool isPatternPlaying = false;

  final UiProjectMetadata metadata = projectMetadataNew();
  final UiAudioHardwareConfig hardwareConfig = audioHardwareConfigNew();

  /// Mixer state of global app state
  final UiMixerState mixerState = UiMixerState();

  // Collections of track state
  final Map<int, UiTrack> tracks = {};
  final Map<int, UiPattern> patterns = {};
  final List<UiPluginInfo> availablePlugins = [];
  final Map<int, ModulationLinkDto> modulationLinks = {};
  final Map<int, AutomationLaneDto> automationPool = {};
  final Map<int, ModulationSourceDto> modulationSources = {};
  final Set<(int, String)> touchedParams = {};

  final int maxSamplesIndex = 2000;

  // =========== EDITOR STATE ====================
  final ToolSelection selectedTool = ToolSelection.pointer;
  final WorkspaceView currentView = WorkspaceView.trackList;
  final ToolbarMenuContextGroup currentToolbarContext = ToolbarMenuContextGroup.none;
  final GridSize piannoRollGridDenom = GridSize.quarter;
  int? editingPatternId;

    // =========== SESSION STATE (frontend-only) ====================
  int? selectedTrackId;
  final List<int> selectedClipIds = [];
  int? focusClipId;
  final bool isMetronomeActive = false;

  final PianoRollToolSelection pianoRollTool = PianoRollToolSelection.grab;
  final double zoomLevelTick = 0.67;

  final Set<int> selectedNoteIds = {};
  int? previewGeneratorId;

  InteractionTarget? interactionTarget;

  /// Denominator of the grid size (e.g 4 = 1/4 note, 16 = 1/16 note)
  final GridSize gridSize = GridSize.quarter;
  final bool snapToGrid = false;

  bool showExportPanel = false;

  FloatingMidiKeyboardFieldState midiKeyboardState =
      FloatingMidiKeyboardFieldState(showed: false);
}
