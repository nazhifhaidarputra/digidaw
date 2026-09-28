import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/plugins/models/plugin_browser_entry.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/features/plugins/services/plugin_favorites_service.dart';
import 'package:karbeat/features/plugins/widgets/plugin_browser_dialog.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

class _BrowserPluginNotifier extends PluginNotifier {
  @override
  Future<PluginState> build() async => _state();
}

class _FavoritesService extends PluginFavoritesService {
  ISet<String> saved = const ISetConst<String>({});

  @override
  Future<Result<ISet<String>>> load() async => Result.ok(saved);

  @override
  Future<Result<void>> save(ISet<String> favorites) async {
    saved = favorites;
    return Result.ok(null);
  }
}

class _SerialFavoritesService extends PluginFavoritesService {
  final List<ISet<String>> writes = [];
  final List<Completer<Result<void>>> completions = [];

  @override
  Future<Result<ISet<String>>> load() async =>
      Result.ok(const ISetConst<String>({}));

  @override
  Future<Result<void>> save(ISet<String> favorites) {
    writes.add(favorites);
    final completion = Completer<Result<void>>();
    completions.add(completion);
    return completion.future;
  }
}

void main() {
  test('filters metadata and pins favorites deterministically', () {
    final state = _state(favorites: const ISetConst<String>({'vst3:vital'}));

    expect(
      filterAndSortPluginEntries(
        state,
        KarbeatPluginType.generator,
        '',
      ).map((entry) => entry.name),
      ['Vital', 'Alpha'],
    );
    expect(
      filterAndSortPluginEntries(
        state,
        KarbeatPluginType.generator,
        'audio',
      ).single.name,
      'Vital',
    );
    expect(
      filterAndSortPluginEntries(
        state,
        KarbeatPluginType.generator,
        'native',
      ).single.name,
      'Alpha',
    );
  });

  test('maps every future-ready external format to a binary type', () {
    expect(
      UiExternalPluginFormat.values.map(pluginBinaryTypeFromExternalFormat),
      [
        PluginBinaryType.vst3,
        PluginBinaryType.lv2,
        PluginBinaryType.clap,
        PluginBinaryType.au,
      ],
    );
  });

  test(
    'serializes rapid favorite writes without losing the newer toggle',
    () async {
      final favorites = _SerialFavoritesService();
      final container = ProviderContainer(
        overrides: [
          audioPluginProvider.overrideWith(_BrowserPluginNotifier.new),
          pluginFavoritesServiceProvider.overrideWithValue(favorites),
        ],
      );
      addTearDown(container.dispose);
      await container.read(audioPluginProvider.future);
      final notifier = container.read(audioPluginProvider.notifier);

      final add = notifier.toggleFavorite('vst3:vital');
      final remove = notifier.toggleFavorite('vst3:vital');
      await Future<void>.delayed(Duration.zero);
      expect(favorites.writes, [
        const ISetConst<String>({'vst3:vital'}),
      ]);
      favorites.completions.first.complete(Result.ok(null));
      expect((await add).isOk(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(favorites.writes.length, 2);
      expect(favorites.writes.last, isEmpty);
      favorites.completions.last.complete(Result.ok(null));
      expect((await remove).isOk(), isTrue);
      expect(
        container.read(audioPluginProvider).requireValue.favoriteKeys,
        isEmpty,
      );
    },
  );

  testWidgets('requires selection, persists a favorite, and adds explicitly', (
    tester,
  ) async {
    final favorites = _FavoritesService();
    PluginBrowserEntry? added;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPluginProvider.overrideWith(_BrowserPluginNotifier.new),
          pluginFavoritesServiceProvider.overrideWithValue(favorites),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PluginBrowserDialog(
              pluginType: KarbeatPluginType.generator,
              onAdd: (plugin) async {
                added = plugin;
                return Result.ok(null);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final add = find.byKey(const ValueKey('add-selected-plugin'));
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    expect(find.text('VST3'), findsOneWidget);
    expect(find.text('Native'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plugin-favorite-vst3:vital')));
    await tester.pumpAndSettle();
    expect(favorites.saved, contains('vst3:vital'));

    await tester.enterText(
      find.byKey(const ValueKey('plugin-browser-search')),
      'vst3',
    );
    await tester.pump();
    expect(find.text('Vital'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    await tester.tap(find.text('Vital'));
    await tester.pump();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(added?.name, 'Vital');
  });

  testWidgets('keeps the browser open when insertion fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPluginProvider.overrideWith(_BrowserPluginNotifier.new),
          pluginFavoritesServiceProvider.overrideWithValue(_FavoritesService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PluginBrowserDialog(
              pluginType: KarbeatPluginType.generator,
              onAdd: (_) async => Result.error(Exception('install rejected')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vital'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-selected-plugin')));
    await tester.pumpAndSettle();

    expect(find.byType(PluginBrowserDialog), findsOneWidget);
    expect(find.text('install rejected'), findsOneWidget);
  });

  testWidgets('effect browser filters generators and submits once while busy', (
    tester,
  ) async {
    final completion = Completer<Result<void>>();
    var submissions = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPluginProvider.overrideWith(_BrowserPluginNotifier.new),
          pluginFavoritesServiceProvider.overrideWithValue(_FavoritesService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PluginBrowserDialog(
              pluginType: KarbeatPluginType.effect,
              onAdd: (_) {
                submissions++;
                return completion.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delay'), findsOneWidget);
    expect(find.text('Vital'), findsNothing);
    await tester.tap(find.text('Delay'));
    await tester.pump();
    final add = find.byKey(const ValueKey('add-selected-plugin'));
    await tester.tap(add);
    await tester.pump();
    await tester.tap(add, warnIfMissed: false);
    await tester.pump();
    expect(submissions, 1);

    completion.complete(Result.ok(null));
    await tester.pumpAndSettle();
    expect(find.byType(PluginBrowserDialog), findsNothing);
  });
}

PluginState _state({ISet<String> favorites = const ISetConst<String>({})}) {
  return PluginState(
    favoriteKeys: favorites,
    registry: PluginRegistry(
      browserEntries: IList([
        const PluginBrowserEntry(
          registryId: 1,
          favoriteKey: 'native:1',
          name: 'Alpha',
          vendor: 'DigiDAW',
          pluginType: KarbeatPluginType.generator,
          binaryType: PluginBinaryType.native,
          isExternal: false,
        ),
        const PluginBrowserEntry(
          registryId: 2,
          favoriteKey: 'vst3:vital',
          name: 'Vital',
          vendor: 'Vital Audio',
          pluginType: KarbeatPluginType.generator,
          binaryType: PluginBinaryType.vst3,
          isExternal: true,
        ),
        const PluginBrowserEntry(
          registryId: 3,
          favoriteKey: 'native:3',
          name: 'Delay',
          vendor: 'DigiDAW',
          pluginType: KarbeatPluginType.effect,
          binaryType: PluginBinaryType.native,
          isExternal: false,
        ),
      ]),
    ),
  );
}
