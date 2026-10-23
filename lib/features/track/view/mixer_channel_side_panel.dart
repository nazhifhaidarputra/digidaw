import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/features/mixer/services/mixer_channel_targets.dart';
import 'package:karbeat/features/mixer/view/channel_output_chip.dart';
import 'package:karbeat/features/mixer/view/mixer_channel_context_menu.dart';
import 'package:karbeat/features/mixer/view/mixer_channel_strip.dart';
import 'package:karbeat/features/mixer/view/mixer_effect_rack.dart';
import 'package:karbeat/features/mixer/view/routing_dialog.dart';
import 'package:karbeat/src/rust/api/mixer.dart';

/// Mixer strip and effect rack of the channel selected in the track list.
class MixerChannelSidePanel extends ConsumerWidget {
  const MixerChannelSidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final target = ref.watch(mixerChannelPanelTargetProvider);
    if (target == null) return const SizedBox.shrink();

    final name = ref.watch(
      projectProvider.select((s) {
        final store = s.value;
        return store == null
            ? ''
            : target.displayName(store.mixer, store.tracks);
      }),
    );
    final node = target.routingNode;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        children: [
          Container(
            height: 30,
            color: colors.surfaceContainer,
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              children: [
                Icon(Icons.tune, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    target is UiMixerChannelTarget_Master
                        ? name
                        : '${target.kindLabel} · $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurface, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Close channel panel',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  onPressed: () => ref
                      .read(trackListStateProvider.notifier)
                      .closeMixerChannelPanel(),
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: MixerChannelContextMenu(
                    target: target,
                    child: MixerChannelStrip(
                      target: target,
                      isSelected: true,
                      footer: target is UiMixerChannelTarget_Master
                          ? null
                          : ChannelOutputChip(
                              source: node,
                              onTap: () => showRoutingDialog(
                                context: context,
                                source: node,
                              ),
                            ),
                    ),
                  ),
                ),
                Container(width: 1, color: colors.outlineVariant),
                Expanded(child: MixerEffectRack(target: target)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
