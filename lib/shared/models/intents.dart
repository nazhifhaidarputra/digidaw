import 'package:flutter/widgets.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}
class SaveProjectIntent extends Intent { const SaveProjectIntent(); }
class NewBlankProjectIntent extends Intent { const NewBlankProjectIntent(); }

class DeleteClipIntent extends Intent { const DeleteClipIntent(); }
class SplitClipIntent extends Intent { const SplitClipIntent(); }
class DuplicateClipIntent extends Intent { const DuplicateClipIntent(); }

class DeleteNoteIntent extends Intent { const DeleteNoteIntent(); }
