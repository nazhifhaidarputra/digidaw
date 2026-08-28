import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/plugins/widgets/sidechain_source_panel.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

void main() {
  const target = UiPluginTarget.trackEffect(trackId: 2, effectId: 3);
  const sourceNode = UiRoutingNode.track(1);

  Widget buildPanel({
    required SidechainSourceLoader loader,
    required SidechainSourceSetter setter,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SidechainSourcePanel(
            target: target,
            loadSources: loader,
            setSource: setter,
          ),
        ),
      ),
    );
  }

  testWidgets('enables, updates, and removes a sidechain send', (tester) async {
    final updates = <(UiRoutingNode, double?)>[];
    await tester.pumpWidget(
      buildPanel(
        loader: () async => const [
          UiSidechainSource(
            source: sourceNode,
            name: 'Kick',
            enabled: false,
            sendLevel: 1.0,
          ),
        ],
        setter: (source, level) async => updates.add((source, level)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kick'), findsOneWidget);
    expect(find.text('Track'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(updates.last.$2, 1.0);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0.5);
    slider.onChangeEnd!(0.5);
    await tester.pumpAndSettle();
    expect(updates.last.$2, 0.5);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(updates.last.$2, isNull);
  });

  testWidgets('rolls back an optimistic toggle when routing fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPanel(
        loader: () async => const [
          UiSidechainSource(
            source: sourceNode,
            name: 'Kick',
            enabled: false,
            sendLevel: 1.0,
          ),
        ],
        setter: (_, _) async => throw Exception('feedback cycle'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.textContaining('feedback cycle'), findsOneWidget);
  });
}
