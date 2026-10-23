import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/mixer/services/mixer_channel_targets.dart';
import 'package:karbeat/features/mixer/view/sidechain_input_dialog.dart';
import 'package:karbeat/features/plugins/services/plugin_ui_launcher.dart';
import 'package:karbeat/features/plugins/widgets/plugin_browser_dialog.dart';
import 'package:karbeat/features/track/view/plugin_automation_parameter_dialog.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

/// Opens the plugin browser and adds the picked effect to [target]'s rack.
Future<void> showAddEffectDialog({
  required BuildContext context,
  required WidgetRef ref,
  required UiMixerChannelTarget target,
}) {
  return showPluginBrowserDialog(
    context: context,
    pluginType: KarbeatPluginType.effect,
    onAdd: (plugin) => ref
        .read(mixerStateProvider.notifier)
        .addEffectToTarget(target, plugin.registryId),
  );
}

/// The effect rack of one mixer channel, titled with the channel's name.
class MixerEffectRack extends ConsumerWidget {
  final UiMixerChannelTarget target;

  const MixerEffectRack({super.key, required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final rack = ref.watch(
      projectProvider.select((s) {
        final store = s.value;
        final channel = store == null ? null : target.channelIn(store.mixer);
        if (store == null || channel == null) return null;
        return (
          name: target.displayName(store.mixer, store.tracks),
          effects: channel.effects,
        );
      }),
    );
    if (rack == null) return const SizedBox.shrink();
    final effects = rack.effects;

    return Container(
      color: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: colors.surfaceContainer,
            child: Row(
              children: [
                Icon(Icons.blur_on, color: colors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${rack.name} Effects',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.transparent,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Effects List
          Expanded(
            child: effects.isEmpty
                ? Center(
                    child: Text(
                      'No effects',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: effects.length,
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) {
                      ref
                          .read(mixerStateProvider.notifier)
                          .moveEffectOrder(
                            target: target,
                            effectId: effects[oldIndex].id,
                            newPosition: newIndex,
                          );
                    },
                    itemBuilder: (context, index) {
                      final effect = effects[index];
                      return Padding(
                        key: ValueKey(effect.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EffectRackItem(
                          effect: effect,
                          index: index,
                          channelTarget: target,
                          pluginTarget: target.effectTarget(effect.id),
                        ),
                      );
                    },
                  ),
          ),

          // Add Effect Button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
              ),
              onPressed: () => showAddEffectDialog(
                context: context,
                ref: ref,
                target: target,
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Effect'),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// Effect Rack Item
// =========================================================

/// One effect slot in the rack: opens the plugin on tap, toggles bypass,
/// and offers slot actions from its context menu.
class _EffectRackItem extends ConsumerWidget {
  final UiEffectSummary effect;
  final int index;
  final UiMixerChannelTarget channelTarget;
  final UiPluginTarget pluginTarget;

  const _EffectRackItem({
    required this.effect,
    required this.index,
    required this.channelTarget,
    required this.pluginTarget,
  });

  Future<void> _openPlugin(BuildContext context, WidgetRef ref) {
    return openPluginInterface(
      context: context,
      ref: ref,
      target: pluginTarget,
      registryId: effect.registryId,
      instanceId: effect.id,
      pluginName: effect.name,
    );
  }

  void _setBypass(WidgetRef ref, bool bypass) {
    ref
        .read(mixerStateProvider.notifier)
        .setEffectBypass(
          target: channelTarget,
          effectId: effect.id,
          bypass: bypass,
        );
  }

  void _remove(WidgetRef ref) {
    ref
        .read(mixerStateProvider.notifier)
        .removeEffectFromTargetMixerChannel(
          target: channelTarget,
          effectId: effect.id,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final enabled = !effect.bypass;

    return ContextMenuWrapper(
      title: effect.name,
      actions: [
        DawContextAction(
          title: 'Open plugin',
          icon: Icons.open_in_new,
          onTap: () => _openPlugin(context, ref),
        ),
        DawContextAction(
          title: 'Sidechain input…',
          icon: Icons.alt_route,
          onTap: () => showSidechainInputDialog(
            context: context,
            target: pluginTarget,
            registryId: effect.registryId,
            pluginName: effect.name,
          ),
        ),
        DawContextAction(
          title: 'Add automation on...',
          icon: Icons.timeline,
          onTap: () => showPluginAutomationParameterDialog(
            context: context,
            target: pluginTarget,
            ownerName: effect.name,
          ),
        ),
        DawContextAction(
          title: enabled ? 'Bypass effect' : 'Enable effect',
          icon: enabled ? Icons.power_off : Icons.power_settings_new,
          onTap: () => _setBypass(ref, enabled),
        ),
        DawContextAction(
          title: 'Remove effect',
          icon: Icons.delete_outline,
          isDestructive: true,
          onTap: () => _remove(ref),
        ),
      ],
      child: Material(
        color: enabled
            ? colors.surfaceContainer
            : colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 4, right: 4),
          leading: IconButton(
            tooltip: enabled ? 'Bypass effect' : 'Enable effect',
            visualDensity: VisualDensity.compact,
            onPressed: () => _setBypass(ref, enabled),
            icon: Icon(
              Icons.power_settings_new,
              color: enabled ? colors.primary : colors.outline,
              size: 16,
            ),
          ),
          minLeadingWidth: 0,
          horizontalTitleGap: 0,
          title: Text(
            effect.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enabled ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
          subtitle: Text(
            enabled ? 'ID: ${effect.id}' : 'Bypassed · ID: ${effect.id}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Remove effect',
                visualDensity: VisualDensity.compact,
                onPressed: () => _remove(ref),
                icon: Icon(Icons.close, color: colors.error, size: 16),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle,
                    color: colors.onSurfaceVariant,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          onTap: () => _openPlugin(context, ref),
        ),
      ),
    );
  }
}
