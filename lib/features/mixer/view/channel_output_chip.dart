import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/mixer/services/routing_labels.dart';
import 'package:karbeat/src/rust/api/mixer.dart';

/// Shows where a channel strip's signal goes: its main output, or "Unlinked",
/// plus how many plugins it keys. Tapping opens the routing editor.
class ChannelOutputChip extends ConsumerWidget {
  const ChannelOutputChip({
    super.key,
    required this.source,
    required this.onTap,
  });

  final UiRoutingNode source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final store = ref.watch(projectProvider).value;
    if (store == null) return const SizedBox.shrink();
    final labels = RoutingLabels(mixer: store.mixer, tracks: store.tracks);
    final routes = store.mixer.routing.where((route) => route.source == source);
    final output = routes.where((route) => !route.isSend).firstOrNull;
    final sidechains = routes
        .where((route) => route.destination is UiRoutingNode_PluginSidechain)
        .length;

    final linked = output != null;
    final label = linked ? labels.channelName(output.destination) : 'Unlinked';
    final color = linked ? colors.primary : colors.tertiary;
    return Tooltip(
      message: linked ? 'Output: $label' : 'Not routed to any output',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    linked ? Icons.arrow_downward : Icons.link_off,
                    size: 10,
                    color: color,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontSize: 9),
                    ),
                  ),
                ],
              ),
              if (sidechains > 0)
                Text(
                  'SC → $sidechains',
                  style: TextStyle(color: colors.secondary, fontSize: 8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
