import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/workspace/services/project_file_actions.dart';

void main() {
  test('project display name is the file name of the project path', () {
    expect(projectDisplayName('/home/user/music/song.dgdaw'), 'song.dgdaw');
    expect(projectDisplayName(r'C:\Music\beat.karbeat'), 'beat.karbeat');
    expect(projectDisplayName(null), 'Untitled');
  });
}
