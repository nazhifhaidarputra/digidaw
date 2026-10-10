import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/workspace/services/project_file_actions.dart';

void main() {
  test('the window title names the project file', () {
    expect(
      projectWindowTitle('/music/song.dgdaw', saved: true),
      'DigiDAW — song.dgdaw',
    );
    expect(projectWindowTitle(null, saved: true), 'DigiDAW — Untitled');
  });

  test('an unsaved project is marked with an asterisk', () {
    expect(
      projectWindowTitle(r'C:\music\song.dgdaw', saved: false),
      'DigiDAW — song.dgdaw*',
    );
    expect(projectWindowTitle(null, saved: false), 'DigiDAW — Untitled*');
  });
}
