import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/workspace/services/project_file_dialogs.dart';

void main() {
  test('the .dgdaw filter has the Digidaw description', () {
    expect(dgdawProjectTypeGroup.label, 'Digidaw Project (.dgdaw)');
    expect(dgdawProjectTypeGroup.extensions, ['dgdaw']);
  });

  test('the legacy project filter stays available for loading', () {
    expect(karbeatProjectTypeGroup.label, 'Karbeat Project (.karbeat)');
    expect(karbeatProjectTypeGroup.extensions, ['karbeat']);
  });

  test('project files are recognised by their extensions', () {
    expect(isSupportedProjectFile('/music/song.dgdaw'), isTrue);
    expect(isSupportedProjectFile(r'C:\music\song.dgdaw'), isTrue);
    expect(isSupportedProjectFile('/music/song.DGDAW'), isTrue);
    expect(isSupportedProjectFile('/music/song.karbeat'), isTrue);
    expect(isSupportedProjectFile('/music/song.wav'), isFalse);
    expect(isSupportedProjectFile('/music/song'), isFalse);
  });

  test('a save path gets exactly the requested extension', () {
    expect(withFileExtension('/music/song', 'dgdaw'), '/music/song.dgdaw');
    expect(
      withFileExtension('/music/song.dgdaw', 'dgdaw'),
      '/music/song.dgdaw',
    );
    expect(
      withFileExtension('/music/song.DGDAW', 'dgdaw'),
      '/music/song.DGDAW',
    );
    expect(withFileExtension('/music/song.txt', 'wav'), '/music/song.wav');
    expect(
      withFileExtension(r'C:\music\song.mp3', 'flac'),
      r'C:\music\song.flac',
    );
  });

  test('audio export filters describe the selected format', () {
    final wav = audioExportTypeGroup('wav');
    expect(wav.label, 'WAV Audio (.wav)');
    expect(wav.extensions, ['wav']);

    final flac = audioExportTypeGroup('flac');
    expect(flac.label, 'FLAC Audio (.flac)');
    expect(flac.extensions, ['flac']);
  });
}
