import 'package:flutter/material.dart';

class TogglePlayIntent extends Intent {
  const TogglePlayIntent();
}

class StopIntent extends Intent {
  const StopIntent();
}

class ToggleLoopIntent extends Intent {
  const ToggleLoopIntent();
}

class ToggleMetronomeIntent extends Intent {
  const ToggleMetronomeIntent();
}

/// Arms the selected audio track to record.
class RecordSelectedTrackIntent extends Intent {
  const RecordSelectedTrackIntent();
}

/// Ends every take and keeps what it recorded.
class StopRecordingIntent extends Intent {
  const StopRecordingIntent();
}
