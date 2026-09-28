import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/mixer/services/routing_labels.dart';
import 'package:karbeat/features/mixer/view/sidechain_target_picker.dart';
import 'package:karbeat/src/rust/api/mixer.dart';

/// Opens the routing editor for a track or bus: its main output, its sends,
/// and the plugins it keys through their sidechain inputs.
Future<void> showRoutingDialog({
  required BuildContext context,
  required UiRoutingNode source,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RoutingDialog(source: source),
  );
}

class _RoutingDialog extends ConsumerWidget {
  const _RoutingDialog({required this.source});

  final UiRoutingNode source;

  MixerNotifier _mixer(WidgetRef ref) => ref.read(mixerStateProvider.notifier);

  Future<void> _setOutput(WidgetRef ref, UiRoutingNode? destination) async {
    final routing = ref.read(projectProvider).value?.mixer.routing ?? [];
    final current = routing
        .where((route) => route.source == source && !route.isSend)
        .firstOrNull;
    if (destination == null) {
      if (current == null) return;
      await _mixer(ref).removeRouting(
        source: source,
        destination: current.destination,
        isSend: false,
      );
      return;
    }
    await _mixer(ref).updateRoutingCall(
      src: source,
      dest: destination,
      sendLvl: 1.0,
      isSend: false,
    );
  }

  Future<void> _addSidechain(BuildContext context, WidgetRef ref) async {
    final plugin = await showSidechainTargetPicker(
      context: context,
      source: source,
    );
    if (plugin == null) return;
    await _mixer(
      ref,
    ).setSidechainSend(plugin: plugin, source: source, sendLevel: 1.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final store = ref.watch(projectProvider).value;
    if (store == null) return const SizedBox.shrink();
    final mixer = store.mixer;
    final labels = RoutingLabels(mixer: mixer, tracks: store.tracks);

    final routes = mixer.routing.where((route) => route.source == source);
    final output = routes.where((route) => !route.isSend).firstOrNull;
    final sends = routes
        .where(
          (route) =>
              route.isSend &&
              route.destination is! UiRoutingNode_PluginSidechain,
        )
        .toList();
    final sidechains = routes
        .where((route) => route.destination is UiRoutingNode_PluginSidechain)
        .toList();

    final outputChoices = [
      const UiRoutingNode.master(),
      for (final id in mixer.buses.keys)
        if (UiRoutingNode.bus(id) != source) UiRoutingNode.bus(id),
    ];
    final sendChoices = outputChoices
        .where(
          (node) =>
              node != output?.destination &&
              !sends.any((send) => send.destination == node),
        )
        .toList();

    return AlertDialog(
      title: Text('Routing · ${labels.channelName(source)}'),
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeader(title: 'OUTPUT'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<UiRoutingNode?>(
                      key: ValueKey(output?.destination),
                      initialValue: output?.destination,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final node in outputChoices)
                          DropdownMenuItem(
                            value: node,
                            child: Text(labels.channelName(node)),
                          ),
                        const DropdownMenuItem<UiRoutingNode?>(
                          value: null,
                          child: Text('None (unlinked)'),
                        ),
                      ],
                      onChanged: (node) => _setOutput(ref, node),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: output == null
                        ? 'Link to master'
                        : 'Unlink from ${labels.channelName(output.destination)}',
                    icon: Icon(output == null ? Icons.link : Icons.link_off),
                    onPressed: () => _setOutput(
                      ref,
                      output == null ? const UiRoutingNode.master() : null,
                    ),
                  ),
                ],
              ),
              if (output == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Unlinked: this channel is heard only through its sends '
                    'and sidechains.',
                    style: TextStyle(color: colors.tertiary, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'SENDS',
                action: PopupMenuButton<UiRoutingNode>(
                  enabled: sendChoices.isNotEmpty,
                  tooltip: 'Add send',
                  onSelected: (node) => _mixer(ref).updateRoutingCall(
                    src: source,
                    dest: node,
                    sendLvl: 0.5,
                    isSend: true,
                  ),
                  itemBuilder: (_) => [
                    for (final node in sendChoices)
                      PopupMenuItem(
                        value: node,
                        child: Text(labels.channelName(node)),
                      ),
                  ],
                  child: const _AddLabel(label: 'Add send'),
                ),
              ),
              if (sends.isEmpty)
                const _EmptyLabel(text: 'No sends.')
              else
                for (final send in sends)
                  _RouteRow(
                    key: ValueKey(('send', send.destination)),
                    icon: Icons.call_split,
                    label: labels.channelName(send.destination),
                    level: send.sendLevel,
                    tap: send.tap,
                    onChanged: (level, tap) => _mixer(ref).updateRoutingCall(
                      src: source,
                      dest: send.destination,
                      sendLvl: level,
                      isSend: true,
                      tap: tap,
                    ),
                    onRemove: () => _mixer(ref).removeRouting(
                      source: source,
                      destination: send.destination,
                      isSend: true,
                    ),
                  ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'SIDECHAINS',
                action: InkWell(
                  onTap: () => _addSidechain(context, ref),
                  child: const _AddLabel(label: 'Add sidechain'),
                ),
              ),
              if (sidechains.isEmpty)
                const _EmptyLabel(
                  text:
                      'Not keying any plugin. Add one to duck another '
                      'channel from this signal.',
                )
              else
                for (final sidechain in sidechains)
                  if (sidechain.destination case UiRoutingNode_PluginSidechain(
                    field0: final plugin,
                  ))
                    _RouteRow(
                      key: ValueKey(('sidechain', plugin)),
                      icon: Icons.alt_route,
                      label: labels.sidechainName(plugin),
                      level: sidechain.sendLevel,
                      tap: sidechain.tap,
                      onChanged: (level, tap) => _mixer(ref).setSidechainSend(
                        plugin: plugin,
                        source: source,
                        sendLevel: level,
                        tap: tap,
                      ),
                      onRemove: () => _mixer(ref).setSidechainSend(
                        plugin: plugin,
                        source: source,
                        sendLevel: null,
                      ),
                    ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _AddLabel extends StatelessWidget {
  const _AddLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16, color: colors.primary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: colors.primary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyLabel extends StatelessWidget {
  const _EmptyLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.outline,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// One send or sidechain: level, pre/post-fader tap, and removal.
///
/// The slider previews locally while dragging and commits on release.
class _RouteRow extends StatefulWidget {
  const _RouteRow({
    super.key,
    required this.icon,
    required this.label,
    required this.level,
    required this.tap,
    required this.onChanged,
    required this.onRemove,
  });

  final IconData icon;
  final String label;
  final double level;
  final UiRoutingTap tap;
  final void Function(double level, UiRoutingTap tap) onChanged;
  final VoidCallback onRemove;

  @override
  State<_RouteRow> createState() => _RouteRowState();
}

class _RouteRowState extends State<_RouteRow> {
  double? _dragLevel;

  String _formatLevel(double linear) {
    if (linear <= 0.0001) return '-∞ dB';
    final db = 20.0 * math.log(linear) / math.ln10;
    return '${db.toStringAsFixed(1)} dB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final level = _dragLevel ?? widget.level;
    final preFader = widget.tap == UiRoutingTap.preFader;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurface),
                ),
              ),
              Tooltip(
                message: 'Tap the signal before the source fader',
                child: FilterChip(
                  label: const Text('PRE'),
                  labelStyle: const TextStyle(fontSize: 10),
                  visualDensity: VisualDensity.compact,
                  selected: preFader,
                  onSelected: (pre) => widget.onChanged(
                    widget.level,
                    pre ? UiRoutingTap.preFader : UiRoutingTap.postFader,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.close, size: 18, color: colors.error),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: level.clamp(0.0, 1.0),
                  onChanged: (value) => setState(() => _dragLevel = value),
                  onChangeEnd: (value) {
                    setState(() => _dragLevel = null);
                    widget.onChanged(value, widget.tap);
                  },
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  _formatLevel(level),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}
