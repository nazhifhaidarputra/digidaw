import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/plugins/services/plugin_ui_launcher.dart';
import 'package:karbeat/features/setting/services/external_plugin_service.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _ProjectNotifier extends ProjectNotifier {
  final DawContext context = _MockDawContext();

  @override
  DawContext get dawContext => context;

  @override
  Future<ApplicationDataStore> build() =>
      Completer<ApplicationDataStore>().future;
}

class _ExternalService extends ExternalPluginService {
  Result<UiExternalPluginDescriptor?> descriptorResult = Result.ok(null);
  Result<UiExternalPluginCapabilities> capabilitiesResult = Result.ok(
    const UiExternalPluginCapabilities(
      controller: true,
      editor: true,
      sidechain: false,
    ),
  );
  Result<void> openResult = Result.ok(null);
  int openCount = 0;

  @override
  Future<Result<UiExternalPluginDescriptor?>> descriptor(
    DawContext context,
    UiPluginTarget target,
  ) async => descriptorResult;

  @override
  Future<Result<UiExternalPluginCapabilities>> capabilities(
    DawContext context,
    UiPluginTarget target,
  ) async => capabilitiesResult;

  @override
  Future<Result<void>> openEditor(
    DawContext context,
    UiPluginTarget target,
  ) async {
    openCount++;
    return openResult;
  }
}

class _FlutterLauncher extends PluginFlutterUiLauncher {
  int openCount = 0;
  bool? forceDynamic;

  @override
  void open(
    BuildContext context, {
    required UiPluginTarget target,
    required int registryId,
    required int instanceId,
    required String pluginName,
    bool forceDynamic = false,
  }) {
    openCount++;
    this.forceDynamic = forceDynamic;
  }
}

const _descriptor = UiExternalPluginDescriptor(
  format: UiExternalPluginFormat.vst3,
  nativeId: 'vital',
  path: '/plugins/Vital.vst3',
  name: 'Vital',
  vendor: 'Vital Audio',
  version: '1',
  instrument: true,
);

void main() {
  testWidgets('opens native editor and widget disposal does not close it', (
    tester,
  ) async {
    final service = _ExternalService()
      ..descriptorResult = Result.ok(_descriptor);
    final flutterLauncher = _FlutterLauncher();
    await _pumpLauncher(tester, service, flutterLauncher);

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(service.openCount, 1);
    expect(flutterLauncher.openCount, 0);
    await tester.pumpWidget(const SizedBox());
    expect(service.openCount, 1);
  });

  testWidgets('uses registered Flutter UI for a native plugin', (tester) async {
    final service = _ExternalService();
    final flutterLauncher = _FlutterLauncher();
    await _pumpLauncher(tester, service, flutterLauncher);

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(flutterLauncher.openCount, 1);
    expect(flutterLauncher.forceDynamic, isFalse);
    expect(service.openCount, 0);
  });

  testWidgets('uses generic parameters when an external editor is absent', (
    tester,
  ) async {
    final service = _ExternalService()
      ..descriptorResult = Result.ok(_descriptor)
      ..capabilitiesResult = Result.ok(
        const UiExternalPluginCapabilities(
          controller: true,
          editor: false,
          sidechain: false,
        ),
      );
    final flutterLauncher = _FlutterLauncher();
    await _pumpLauncher(tester, service, flutterLauncher);

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(flutterLauncher.openCount, 1);
    expect(flutterLauncher.forceDynamic, isTrue);
    expect(service.openCount, 0);
  });

  testWidgets('reports editor failure and falls back to generic parameters', (
    tester,
  ) async {
    final service = _ExternalService()
      ..descriptorResult = Result.ok(_descriptor)
      ..openResult = Result.error(Exception('editor rejected'));
    final flutterLauncher = _FlutterLauncher();
    final container = await _pumpLauncher(tester, service, flutterLauncher);

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(flutterLauncher.forceDynamic, isTrue);
    expect(
      container.read(notificationProvider).current?.message,
      'editor rejected',
    );
  });
}

Future<ProviderContainer> _pumpLauncher(
  WidgetTester tester,
  ExternalPluginService service,
  PluginFlutterUiLauncher flutterLauncher,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectProvider.overrideWith(_ProjectNotifier.new),
        externalPluginServiceProvider.overrideWithValue(service),
        pluginFlutterUiLauncherProvider.overrideWithValue(flutterLauncher),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => openPluginInterface(
              context: context,
              ref: ref,
              target: const UiPluginTarget.generator(9),
              registryId: 12,
              instanceId: 9,
              pluginName: 'Vital',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.text('Open')));
}
