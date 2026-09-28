import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/plugins/models/plugin_browser_entry.dart';
import 'package:karbeat/features/plugins/services/plugin_favorites_service.dart';
import 'package:karbeat/features/setting/services/external_plugin_service.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';

part 'audio_plugins_service.freezed.dart';

@freezed
abstract class PluginRegistry with _$PluginRegistry {
  const factory PluginRegistry({
    @Default(IListConst<UiPluginInfo>([])) IList<UiPluginInfo> availablePlugins,
    @Default(IListConst<PluginBrowserEntry>([]))
    IList<PluginBrowserEntry> browserEntries,
  }) = _PluginRegistry;
}

@freezed
abstract class PluginState with _$PluginState {
  const factory PluginState({
    @Default(PluginRegistry()) PluginRegistry registry,
    @Default(ISetConst<String>({})) ISet<String> favoriteKeys,
    @Default(ISetConst<String>({})) ISet<String> pendingFavoriteKeys,
  }) = _PluginState;
}

class PluginNotifier extends AsyncNotifier<PluginState> {
  DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;
  Future<void> _favoriteWriteTail = Future.value();

  @override
  Future<PluginState> build() async {
    // Await the Project Provider to ensure the DawContext is fully initialized first

    final favorites = await ref.read(pluginFavoritesServiceProvider).load();
    if (favorites case Error<ISet<String>>(error: final error)) {
      AppLogger.error('Failed to load plugin favorites: $error');
      ref.notifyError(error, title: 'Could not load plugin favorites');
    }

    final refreshed = await _loadRegistry();
    if (refreshed case Error<PluginRegistry>(error: final error)) {
      AppLogger.error('Failed to initialize plugin registry: $error');
      ref.notifyError(error, title: 'Could not load plugins');
    }
    return PluginState(
      registry: refreshed.isOk() ? refreshed.ok() : const PluginRegistry(),
      favoriteKeys: favorites.isOk()
          ? favorites.ok()
          : const ISetConst<String>({}),
    );
  }

  Future<Result<PluginRegistry>> _loadRegistry() async {
    final external = await ref
        .read(externalPluginServiceProvider)
        .refreshCatalog(_ctx);
    if (external case Error<List<UiExternalPluginEntry>>(error: final error)) {
      return Result.error(error);
    }
    final plugins = await attemptAsync(
      () => getAvailablePluginsWithIds(ctx: _ctx),
    );
    if (plugins case Error<List<UiPluginInfo>>(error: final error)) {
      return Result.error(error);
    }
    return Result.ok(_buildRegistry(plugins.ok(), external.ok()));
  }

  PluginRegistry _buildRegistry(
    List<UiPluginInfo> plugins,
    List<UiExternalPluginEntry> externalEntries,
  ) {
    final externalById = {
      for (final entry in externalEntries)
        if (entry.available) entry.id: entry,
    };
    final browserEntries = plugins.map((plugin) {
      final external = externalById[plugin.id];
      if (external == null) {
        return PluginBrowserEntry(
          registryId: plugin.id,
          favoriteKey: 'native:${plugin.id}',
          name: plugin.name,
          vendor: 'DigiDAW',
          pluginType: plugin.pluginType,
          binaryType: PluginBinaryType.native,
          isExternal: false,
        );
      }
      final descriptor = external.descriptor;
      final binaryType = pluginBinaryTypeFromExternalFormat(descriptor.format);
      return PluginBrowserEntry(
        registryId: plugin.id,
        favoriteKey: '${descriptor.format.name}:${descriptor.nativeId}',
        name: descriptor.name,
        vendor: descriptor.vendor,
        pluginType: plugin.pluginType,
        binaryType: binaryType,
        isExternal: true,
      );
    }).toIList();
    return PluginRegistry(
      availablePlugins: plugins.toIList(),
      browserEntries: browserEntries,
    );
  }

  Future<Result<void>> refreshCatalog() async {
    final refreshed = await _loadRegistry();
    if (refreshed case Error<PluginRegistry>(error: final error)) {
      AppLogger.error('Failed to refresh plugin registry: $error');
      return ref.notifyErrorResult(error, title: 'Could not refresh plugins');
    }
    final current = await future;
    state = AsyncData(current.copyWith(registry: refreshed.ok()));
    return Result.ok(null);
  }

  // ------------------------------------------------------------------
  // Synchronisation Actions
  // ------------------------------------------------------------------

  Future<void> fetchAvailableGenerators() async {
    await refreshCatalog();
  }

  Future<void> fetchAvailableEffects() async {
    await refreshCatalog();
  }

  // ------------------------------------------------------------------
  // UI Getters
  // ------------------------------------------------------------------

  /// Returns a clean list of generators synchronously.
  /// Safe to call directly from the UI once the provider `hasValue`.
  Future<List<UiPluginInfo>> getAvailableGenerators() async {
    // Awaiting `future` guarantees build() has finished and state.hasValue is true!
    final currentState = await future;
    return currentState.registry.availablePlugins
        .where((plugin) => plugin.pluginType == KarbeatPluginType.generator)
        .toList();
  }

  /// Returns a clean list of effects. Awaits the initial load if necessary.
  Future<List<UiPluginInfo>> getAvailableEffects() async {
    final currentState = await future;
    return currentState.registry.availablePlugins
        .where((plugin) => plugin.pluginType == KarbeatPluginType.effect)
        .toList();
  }

  Future<List<PluginBrowserEntry>> getBrowserEntries(
    KarbeatPluginType pluginType, {
    String query = '',
  }) async {
    final current = await future;
    return filterAndSortPluginEntries(current, pluginType, query);
  }

  Future<Result<void>> toggleFavorite(String favoriteKey) {
    final completer = Completer<Result<void>>();
    _favoriteWriteTail = _favoriteWriteTail.then((_) async {
      final current = await future;
      if (current.pendingFavoriteKeys.contains(favoriteKey)) {
        completer.complete(Result.ok(null));
        return;
      }
      state = AsyncData(
        current.copyWith(
          pendingFavoriteKeys: current.pendingFavoriteKeys.add(favoriteKey),
        ),
      );
      final nextFavorites = current.favoriteKeys.contains(favoriteKey)
          ? current.favoriteKeys.remove(favoriteKey)
          : current.favoriteKeys.add(favoriteKey);
      final saved = await ref
          .read(pluginFavoritesServiceProvider)
          .save(nextFavorites);
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(
          favoriteKeys: saved.isOk() ? nextFavorites : latest.favoriteKeys,
          pendingFavoriteKeys: latest.pendingFavoriteKeys.remove(favoriteKey),
        ),
      );
      if (saved case Error<void>(error: final error)) {
        AppLogger.error('Failed to save plugin favorites: $error');
        final notified = ref.notifyErrorResult(
          error,
          title: 'Could not save plugin favorite',
        );
        completer.complete(notified);
      } else {
        completer.complete(Result.ok(null));
      }
    });
    return completer.future;
  }
}

List<PluginBrowserEntry> filterAndSortPluginEntries(
  PluginState state,
  KarbeatPluginType pluginType,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  final entries = state.registry.browserEntries
      .where((entry) => entry.pluginType == pluginType)
      .where((entry) {
        if (normalizedQuery.isEmpty) return true;
        return entry.name.toLowerCase().contains(normalizedQuery) ||
            entry.vendor.toLowerCase().contains(normalizedQuery) ||
            entry.binaryType.label.toLowerCase().contains(normalizedQuery);
      })
      .toList();
  entries.sort((left, right) {
    final leftFavorite = state.favoriteKeys.contains(left.favoriteKey);
    final rightFavorite = state.favoriteKeys.contains(right.favoriteKey);
    if (leftFavorite != rightFavorite) return leftFavorite ? -1 : 1;
    final name = left.name.toLowerCase().compareTo(right.name.toLowerCase());
    if (name != 0) return name;
    final format = left.binaryType.label.toLowerCase().compareTo(
      right.binaryType.label.toLowerCase(),
    );
    if (format != 0) return format;
    return left.registryId.compareTo(right.registryId);
  });
  return entries;
}

final audioPluginProvider = AsyncNotifierProvider<PluginNotifier, PluginState>(
  PluginNotifier.new,
);

PluginBinaryType pluginBinaryTypeFromExternalFormat(
  UiExternalPluginFormat format,
) => switch (format) {
  UiExternalPluginFormat.vst3 => PluginBinaryType.vst3,
  UiExternalPluginFormat.lv2 => PluginBinaryType.lv2,
  UiExternalPluginFormat.clap => PluginBinaryType.clap,
  UiExternalPluginFormat.au => PluginBinaryType.au,
};
