import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/telemetry_polling_suppression.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/plugins/plugin_registry.dart';
import 'package:karbeat/features/plugins/view/dynamic_plugin_screen.dart';
import 'package:karbeat/features/setting/services/external_plugin_service.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

class PluginFlutterUiLauncher {
  void open(
    BuildContext context, {
    required UiPluginTarget target,
    required int registryId,
    required int instanceId,
    required String pluginName,
    bool forceDynamic = false,
  }) {
    Widget screen;
    if (forceDynamic) {
      screen = DynamicPluginScreen(target: target, pluginName: pluginName);
    } else {
      try {
        screen = PluginRegistryFlutter.getScreen(
          registryId: registryId,
          instanceId: instanceId,
          target: target,
        );
      } on Exception {
        screen = DynamicPluginScreen(target: target, pluginName: pluginName);
      }
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

final pluginFlutterUiLauncherProvider = Provider<PluginFlutterUiLauncher>(
  (ref) => PluginFlutterUiLauncher(),
);

Future<void> openPluginInterface({
  required BuildContext context,
  required WidgetRef ref,
  required UiPluginTarget target,
  required int registryId,
  required int instanceId,
  required String pluginName,
}) async {
  await (() async {
    final service = ref.read(externalPluginServiceProvider);
    final dawContext = ref.read(projectProvider.notifier).dawContext;
    final descriptor = await service.descriptor(dawContext, target);
    if (descriptor case Error<UiExternalPluginDescriptor?>(
      error: final error,
    )) {
      _notifyEditorFailure(ref, error);
      return;
    }

    if (descriptor.ok() == null) {
      if (!context.mounted) return;
      ref
          .read(pluginFlutterUiLauncherProvider)
          .open(
            context,
            target: target,
            registryId: registryId,
            instanceId: instanceId,
            pluginName: pluginName,
          );
      return;
    }

    final capabilities = await service.capabilities(dawContext, target);
    if (capabilities case Error<UiExternalPluginCapabilities>(
      error: final error,
    )) {
      _notifyEditorFailure(ref, error);
      return;
    }
    if (capabilities.ok().editor) {
      final opened = await service.openEditor(dawContext, target);
      if (opened.isOk()) return;
      _notifyEditorFailure(ref, opened.err());
      if (!capabilities.ok().controller || !context.mounted) return;
    }
    if (!context.mounted) return;
    ref
        .read(pluginFlutterUiLauncherProvider)
        .open(
          context,
          target: target,
          registryId: registryId,
          instanceId: instanceId,
          pluginName: pluginName,
          forceDynamic: true,
        );
  }).suppressesTelemetryPolling(
    ref.read(telemetryPollingSuppressionProvider.notifier),
  )();
}

void _notifyEditorFailure(WidgetRef ref, Exception error) {
  AppLogger.error('Could not open plugin interface: $error');
  ref
      .read(notificationProvider.notifier)
      .error(error, title: 'Could not open plugin interface');
}
