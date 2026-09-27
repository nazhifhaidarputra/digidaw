import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/mixer/services/routing_labels.dart';
import 'package:karbeat/features/plugins/services/sidechain_support.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

/// Asks which plugin [source] should key through its sidechain input.
///
/// [onlyChannel] limits the choices to the effects of one channel, for the
/// "sidechain this into that channel" flow started from a destination strip.
Future<UiPluginTarget?> showSidechainTargetPicker({
  required BuildContext context,
  required UiRoutingNode source,
  UiRoutingNode? onlyChannel,
}) {
  return showDialog<UiPluginTarget>(
    context: context,
    builder: (_) =>
        _SidechainTargetPicker(source: source, onlyChannel: onlyChannel),
  );
}

class _SidechainTargetPicker extends ConsumerWidget {
  const _SidechainTargetPicker({required this.source, this.onlyChannel});

  final UiRoutingNode source;
  final UiRoutingNode? onlyChannel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final store = ref.watch(projectProvider).value;
    if (store == null) return const SizedBox.shrink();
    final labels = RoutingLabels(mixer: store.mixer, tracks: store.tracks);

    final trackIds = store.mixer.channels.keys.toList()..sort();
    final channels = onlyChannel != null
        ? [onlyChannel!]
        : [
            for (final id in trackIds) UiRoutingNode.track(id),
            for (final id in store.mixer.buses.keys) UiRoutingNode.bus(id),
            const UiRoutingNode.master(),
          ];
    final keyed = {
      for (final route in store.mixer.routing)
        if (route.destination case UiRoutingNode_PluginSidechain(
          :final field0,
        ) when route.source == source)
          field0,
    };

    final sections = <Widget>[
      for (final channel in channels)
        if (channel != source)
          _ChannelSection(
            name: labels.channelName(channel),
            children: [
              for (final effect in labels.effectsOf(channel))
                if (labels.effectTarget(channel, effect.id) case final target?)
                  _TargetTile(
                    target: target,
                    effect: effect,
                    alreadyKeyed: keyed.contains(target),
                  ),
            ],
          ),
    ];

    return AlertDialog(
      title: Text('Sidechain ${labels.channelName(source)} into…'),
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      content: SizedBox(
        width: 420,
        child: sections.isEmpty
            ? Text(
                'A channel cannot key its own plugins.',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: sections,
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ChannelSection extends StatelessWidget {
  const _ChannelSection({required this.name, required this.children});

  final String name;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name.toUpperCase(),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No effects. Add a sidechain-capable plugin to this channel.',
                style: TextStyle(color: colors.outline, fontSize: 12),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

/// One effect the source could key; enabled once its sidechain input is
/// confirmed.
class _TargetTile extends ConsumerStatefulWidget {
  const _TargetTile({
    required this.target,
    required this.effect,
    required this.alreadyKeyed,
  });

  final UiPluginTarget target;
  final UiEffectSummary effect;
  final bool alreadyKeyed;

  @override
  ConsumerState<_TargetTile> createState() => _TargetTileState();
}

class _TargetTileState extends ConsumerState<_TargetTile> {
  late final Future<Result<bool>> _support = sidechainInputSupport(
    ref,
    widget.target,
    widget.effect.registryId,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Result<bool>>(
      future: _support,
      builder: (context, snapshot) {
        final (subtitle, selectable) = switch (snapshot.data) {
          _ when widget.alreadyKeyed => ('Already keyed', false),
          null => ('Checking inputs…', false),
          Ok(value: true) => ('Sidechain input', true),
          Ok() => ('No sidechain input', false),
          // The pick still works if the plugin does have an aux input.
          Error() => ('Could not confirm a sidechain input', true),
        };
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(
            widget.alreadyKeyed ? Icons.check_circle : Icons.input,
            size: 18,
            color: selectable ? colors.primary : colors.outline,
          ),
          title: Text(widget.effect.name),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
          enabled: selectable,
          onTap: () => Navigator.pop(context, widget.target),
        );
      },
    );
  }
}
