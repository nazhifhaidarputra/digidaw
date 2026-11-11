import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

class PluginFavoritesService {
  Future<Result<ISet<String>>> load() {
    return attemptAsync(
      () async => (await settings_api.loadPluginFavorites()).toISet(),
    );
  }

  Future<Result<void>> save(ISet<String> favorites) {
    return attemptAsync(
      () => settings_api.savePluginFavorites(ids: favorites.toList()),
    );
  }
}

final pluginFavoritesServiceProvider = Provider<PluginFavoritesService>((ref) {
  return PluginFavoritesService();
});
