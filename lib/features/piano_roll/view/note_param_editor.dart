import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Note param editor panel for easily edit note param (Velocity, Pitch)
/// Digidaw supports smooth param modulation from here, so you can have a
/// linear plot going down for example for single not from start to end of note, to make a pitch swinging effect into
/// your note, or adding a rich sound through varying velocity of notes.
/// 
/// It is inspired by FL Studio note param editor + additional feature Digidaw provide
/// 
/// Note that note all plugin hosting API supports this kind of note behavior,
/// so you would expect that some features are not working
class NoteParamEditorPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return NoteParamEditorPanelState();
  }

}

class NoteParamEditorPanelState extends ConsumerState<NoteParamEditorPanel> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      child: Text(
        "Note param editor"
      ),
    );
  }

}