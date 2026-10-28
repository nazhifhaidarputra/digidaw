String formatTimeFromSamples(int playheadSamples, int sampleRate) {
  final totalSeconds = playheadSamples / sampleRate;

  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).floor();

  // Milliseconds (2-digit precision)
  final ms = ((totalSeconds - totalSeconds.floor()) * 100).floor();

  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  final mms = ms.toString().padLeft(2, '0');

  return "$mm:$ss:$mms";
}

/// Note names for the twelve pitch classes, ordered from C to B.
const List<String> midiPitchClassNames = [
  "C",
  "C#",
  "D",
  "D#",
  "E",
  "F",
  "F#",
  "G",
  "G#",
  "A",
  "A#",
  "B",
];

/// Scientific pitch octave of a MIDI note, where C4 is note 60.
int midiKeyOctave(int key) => key ~/ 12 - 1;

/// Pitch class of a MIDI note, `0` for C through `11` for B.
int midiKeyPitchClass(int key) => key % 12;

/// Name of a pitch class, `0` for C through `11` for B.
String midiPitchClassName(int pitchClass) =>
    midiPitchClassNames[pitchClass % 12];

String numToMidiKey(int key) {
  return "${midiPitchClassName(midiKeyPitchClass(key))}"
      "${midiKeyOctave(key)}";
}
