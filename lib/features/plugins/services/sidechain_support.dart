import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/external_plugin_service.dart';
import 'package:karbeat/generated/plugins/plugins.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

/// First-party effects whose DSP reads their auxiliary input.
const firstPartySidechainEffects = {DigidawSidechainCompressorSpecs.id};

/// Whether the effect at [target] has a sidechain input: first-party effects
/// by registry, hosted plugins by the host's bus capabilities.
Future<Result<bool>> sidechainInputSupport(
  WidgetRef ref,
  UiPluginTarget target,
  int registryId,
) async {
  if (firstPartySidechainEffects.contains(registryId)) {
    return Result.ok(true);
  }
  final service = ref.read(externalPluginServiceProvider);
  final dawContext = ref.read(projectProvider.notifier).dawContext;
  final descriptor = await service.descriptor(dawContext, target);
  switch (descriptor) {
    case Error<UiExternalPluginDescriptor?>(:final error):
      return Result.error(error);
    case Ok<UiExternalPluginDescriptor?>(value: null):
      return Result.ok(false);
    case Ok<UiExternalPluginDescriptor?>():
      break;
  }
  final capabilities = await service.capabilities(dawContext, target);
  return switch (capabilities) {
    Ok<UiExternalPluginCapabilities>(:final value) => Result.ok(
      value.sidechain,
    ),
    Error<UiExternalPluginCapabilities>(:final error) => Result.error(error),
  };
}
