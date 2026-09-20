import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PluginFavoritesService {
  static const storageKey = 'plugins.favorites.v1';

  Future<Result<ISet<String>>> load() {
    return attemptAsync(() async {
      final values =
          await SharedPreferencesAsync().getStringList(storageKey) ?? const [];
      return values.toISet();
    });
  }

  Future<Result<void>> save(ISet<String> favorites) {
    return attemptAsync(() async {
      final values = favorites.toList()..sort();
      await SharedPreferencesAsync().setStringList(storageKey, values);
    });
  }
}

final pluginFavoritesServiceProvider = Provider<PluginFavoritesService>((ref) {
  return PluginFavoritesService();
});
