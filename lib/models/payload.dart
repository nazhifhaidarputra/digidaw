// =================================
// PAYLOAD TYPES
// =================================

class NewNotePayload {
  final int patternId;
  final int key;
  final int startTick;
  final int duration;

  const NewNotePayload({
    required this.patternId,
    required this.key,
    required this.startTick,
    required this.duration,
  });
}

// class DeleteNotePayload {
//   final int 
// }
