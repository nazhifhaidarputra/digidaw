import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/mixer/services/mixer_channel_targets.dart';
import 'package:karbeat/features/mixer/services/routing_labels.dart';
import 'package:karbeat/features/mixer/view/bus_identity_actions.dart';
import 'package:karbeat/features/mixer/view/mixer_channel_strip.dart';
import 'package:karbeat/features/mixer/view/mixer_effect_rack.dart';
import 'package:karbeat/features/mixer/view/routing_dialog.dart';
import 'package:karbeat/features/mixer/view/sidechain_target_picker.dart';
import 'package:karbeat/src/rust/api/mixer.dart';

/// Picks a plugin to key from [source] and sends [source] into its sidechain.
/// With [onlyChannel], only plugins on that channel are offered.
Future<void> keySidechainFrom({
  required BuildContext context,
  required WidgetRef ref,
  required UiRoutingNode source,
  UiRoutingNode? onlyChannel,
}) async {
  final plugin = await showSidechainTargetPicker(
    context: context,
    source: source,
    onlyChannel: onlyChannel,
  );
  if (plugin == null) return;
  await ref
      .read(mixerStateProvider.notifier)
      .setSidechainSend(plugin: plugin, source: source, sendLevel: 1.0);
}

/// Right-click menu of a mixer channel: a summary of the channel, then its
/// mute, solo, effect, routing and bus actions.
class MixerChannelContextMenu extends ConsumerWidget {
  final UiMixerChannelTarget target;
  final Widget child;

  /// Actions of the hosting screen, listed after the channel's own.
  final List<DawContextAction> extraActions;

  const MixerChannelContextMenu({
    super.key,
    required this.target,
    required this.child,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final store = ref.watch(projectProvider).value;
    final channel = store == null ? null : target.channelIn(store.mixer);
    if (store == null || channel == null) return child;

    final labels = RoutingLabels(mixer: store.mixer, tracks: store.tracks);
    final node = target.routingNode;
    final name = labels.channelName(node);
    final color = target.colorIn(store.mixer, store.tracks);
    final output = store.mixer.routing
        .where((route) => route.source == node && !route.isSend)
        .firstOrNull;
    final mixer = ref.read(mixerStateProvider.notifier);
    final isMaster = target is UiMixerChannelTarget_Master;
    const master = UiRoutingNode.master();

    final effectCount = channel.effects.length;
    final info = [
      ('Name', name),
      ('Type', target.kindLabel),
      if (target.channelId case final id?) ('ID', '$id'),
      ('Volume', formatChannelVolume(channel.volume)),
      ('Pan', formatChannelPan(channel.pan)),
      (
        'State',
        [
          if (channel.mute) 'Muted',
          if (channel.solo) 'Soloed',
          if (!channel.mute && !channel.solo) 'Active',
        ].join(', '),
      ),
      if (!isMaster)
        (
          'Output',
          output == null ? 'None' : labels.channelName(output.destination),
        ),
      ('Effects', effectCount == 0 ? 'None' : '$effectCount'),
    ];
    final infoStyle = TextStyle(color: colors.onSurface, fontSize: 13);

    return ContextMenuWrapper(
      title: name,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in info)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('$label: $value', style: infoStyle),
            ),
          if (color != null)
            Row(
              children: [
                Text('Color: ', style: infoStyle),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        DawContextAction(
          title: channel.mute ? 'Unmute' : 'Mute',
          icon: channel.mute ? Icons.volume_up : Icons.volume_off,
          onTap: () => mixer.setChannelParam(
            target: target,
            param: UiMixerChannelParams.mute(!channel.mute),
          ),
        ),
        DawContextAction(
          title: channel.solo ? 'Unsolo' : 'Solo',
          icon: Icons.headphones,
          onTap: () => mixer.setChannelParam(
            target: target,
            param: UiMixerChannelParams.solo(!channel.solo),
          ),
        ),
        DawContextAction(
          title: 'Add effect…',
          icon: Icons.add,
          onTap: () =>
              showAddEffectDialog(context: context, ref: ref, target: target),
        ),
        if (target case UiMixerChannelTarget_Bus(:final field0))
          ...busIdentityActions(
            context: context,
            ref: ref,
            busId: field0,
            name: name,
            color: color ?? colors.primary,
          ),
        if (!isMaster) ...[
          DawContextAction(
            title: 'Routing…',
            icon: Icons.account_tree,
            onTap: () => showRoutingDialog(context: context, source: node),
          ),
          if (output?.destination == master)
            DawContextAction(
              title: 'Unlink from master',
              icon: Icons.link_off,
              onTap: () => mixer.removeRouting(
                source: node,
                destination: master,
                isSend: false,
              ),
            )
          else
            DawContextAction(
              title: 'Route to master',
              icon: Icons.link,
              onTap: () => mixer.updateRoutingCall(
                src: node,
                dest: master,
                sendLvl: 1.0,
                isSend: false,
              ),
            ),
          DawContextAction(
            title: 'Sidechain this channel into…',
            icon: Icons.alt_route,
            onTap: () =>
                keySidechainFrom(context: context, ref: ref, source: node),
          ),
        ],
        ...extraActions,
        if (target case UiMixerChannelTarget_Bus(:final field0))
          DawContextAction(
            title: 'Delete Bus',
            icon: Icons.delete,
            isDestructive: true,
            onTap: () => mixer.removeBus(busId: field0),
          ),
      ],
      child: child,
    );
  }
}
