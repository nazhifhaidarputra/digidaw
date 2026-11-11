import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

/// Reads and edits the recent projects list. Rust adds a project to it
/// whenever one is loaded or saved, moving a listed project to the front.
class RecentProjectsService {
  Future<Result<IList<settings_api.UiRecentProject>>> load() {
    return attemptAsync(
      () async => (await settings_api.loadRecentProjects()).lock,
    );
  }

  Future<Result<void>> remove(String path) {
    return attemptAsync(() => settings_api.removeRecentProject(path: path));
  }

  Future<Result<void>> clear() {
    return attemptAsync(settings_api.clearRecentProjects);
  }
}

final recentProjectsServiceProvider = Provider<RecentProjectsService>(
  (ref) => RecentProjectsService(),
);

/// Recent projects, most recent first. Read again each time something
/// listens, so a project opened since the last look is included.
final recentProjectsProvider =
    FutureProvider.autoDispose<IList<settings_api.UiRecentProject>>((
      ref,
    ) async {
      final loaded = await ref.read(recentProjectsServiceProvider).load();
      return switch (loaded) {
        Ok(:final value) => value,
        Error(:final error) => throw error,
      };
    });
