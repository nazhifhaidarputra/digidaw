import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/mixer/services/mixer_channel_targets.dart';
import 'package:karbeat/features/mixer/services/routing_labels.dart';
import 'package:karbeat/features/mixer/view/channel_output_chip.dart';
import 'package:karbeat/features/mixer/view/mixer_channel_context_menu.dart';
import 'package:karbeat/features/mixer/view/mixer_channel_strip.dart';
import 'package:karbeat/features/mixer/view/mixer_effect_rack.dart';
import 'package:karbeat/features/mixer/view/routing_dialog.dart';
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/mixer.dart'
    show UiMixerChannelTarget, UiMixerChannelTarget_Master;
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:multi_split_view/multi_split_view.dart';

class MixerScreen extends ConsumerStatefulWidget {
  const MixerScreen({super.key});

  @override
  ConsumerState<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends ConsumerState<MixerScreen> {
  /// The channel whose effect rack is shown.
  UiMixerChannelTarget? _selected;

  late final MultiSplitViewController _splitController;
  final Map<String, GlobalKey> _stripKeys = {};
  late final ScrollController _trackScrollController;
  late final ScrollController _busScrollController;

  // Key to track the exact coordinates of the drawing canvas
  final GlobalKey _overlayKey = GlobalKey();

  static const double _rackWidth = 250;

  @override
  void initState() {
    super.initState();

    _trackScrollController = ScrollController();
    _busScrollController = ScrollController();

    _splitController = MultiSplitViewController(
      areas: [
        Area(
          size: 400,
          min: 150,
          builder: (context, area) => _buildTracksArea(context, area),
        ),
        Area(
          min: 0.1,
          builder: (context, area) => _buildBusesArea(context, area),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _trackScrollController.dispose();
    _busScrollController.dispose();
    super.dispose();
  }

  /// A strip with its context menu, registered for the routing cable overlay.
  Widget _buildStrip(UiMixerChannelTarget target) {
    final node = target.routingNode;
    final isMaster = target is UiMixerChannelTarget_Master;
    return Container(
      key: _stripKeys.putIfAbsent(_stripKeyOf(node)!, () => GlobalKey()),
      child: MixerChannelContextMenu(
        target: target,
        extraActions: _sidechainSelectedActions(node),
        child: MixerChannelStrip(
          target: target,
          isSelected: _selected == target,
          onTap: () => setState(() => _selected = target),
          footer: isMaster
              ? null
              : ChannelOutputChip(
                  source: node,
                  onTap: () =>
                      showRoutingDialog(context: context, source: node),
                ),
        ),
      ),
    );
  }

  /// The FL-style "sidechain the selected channel to this one" entry, offered
  /// when another track or bus is selected.
  List<DawContextAction> _sidechainSelectedActions(
    mixer_api.UiRoutingNode node,
  ) {
    final selected = _selected;
    if (selected == null || selected is UiMixerChannelTarget_Master) {
      return const [];
    }
    final source = selected.routingNode;
    final store = ref.read(projectProvider).value;
    if (store == null || source == node) return const [];
    final labels = RoutingLabels(mixer: store.mixer, tracks: store.tracks);
    return [
      DawContextAction(
        title: 'Sidechain "${labels.channelName(source)}" to this channel…',
        icon: Icons.call_merge,
        onTap: () => keySidechainFrom(
          context: context,
          ref: ref,
          source: source,
          onlyChannel: node,
        ),
      ),
    ];
  }

  Widget _buildTracksArea(BuildContext context, Area area) {
    return Consumer(
      builder: (context, ref, _) {
        final channels = ref.watch(
          projectProvider.select((s) => s.value?.mixer.channels),
        );
        if (channels == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final trackIds = channels.keys.toList()..sort();
        if (trackIds.isEmpty) {
          final colors = Theme.of(context).colorScheme;
          return Center(
            child: Text(
              'No channels',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _trackScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          itemCount: trackIds.length,
          itemBuilder: (context, index) {
            final trackId = trackIds[index];
            return KeyedSubtree(
              key: ValueKey('mixer_track_$trackId'),
              child: _buildStrip(UiMixerChannelTarget.track(trackId)),
            );
          },
        );
      },
    );
  }

  Widget _buildBusesArea(BuildContext context, Area area) {
    return Consumer(
      builder: (context, ref, _) {
        final buses = ref.watch(
          projectProvider.select((s) => s.value?.mixer.buses),
        );
        if (buses == null) return const SizedBox.shrink();
        final busIds = buses.keys.toList();

        return ListView.builder(
          controller: _busScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          itemCount: busIds.length + 1,
          itemBuilder: (context, index) {
            final colors = Theme.of(context).colorScheme;
            // Last item: "Add Bus" ghost strip
            if (index == busIds.length) {
              return GestureDetector(
                onTap: () async {
                  final busCount = busIds.length + 1;
                  await ref
                      .read(mixerStateProvider.notifier)
                      .createNewBusChannel(name: "Bus $busCount");
                },
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.outlineVariant, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: colors.onSurfaceVariant,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add Bus',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final busId = busIds[index];
            return KeyedSubtree(
              key: ValueKey('mixer_bus_$busId'),
              child: _buildStrip(UiMixerChannelTarget.bus(busId)),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final routing = ref.watch(
      projectProvider.select((s) => s.value?.mixer.routing),
    );
    if (routing == null) return const SizedBox.shrink();
    final selected = _selected;

    return Scaffold(
      body: Stack(
        key: _overlayKey,
        children: [
          Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // === MultiSplitView replacing Tracks and Buses ===
                    Expanded(
                      child: MultiSplitViewTheme(
                        data: MultiSplitViewThemeData(
                          dividerPainter: DividerPainters.grooved1(
                            color: colors.outlineVariant,
                            highlightedColor: colors.primary,
                          ),
                        ),
                        child: MultiSplitView(controller: _splitController),
                      ),
                    ),

                    // === Divider ===
                    Container(width: 1, color: colors.outlineVariant),

                    // === Master Channel (fixed) ===
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _buildStrip(const UiMixerChannelTarget.master()),
                    ),

                    // === Divider ===
                    Container(width: 1, color: colors.outlineVariant),

                    // === Effect Rack Panel ===
                    SizedBox(
                      width: _rackWidth,
                      child: selected == null
                          ? Center(
                              child: Text(
                                'Select a channel to\nview effects',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : MixerEffectRack(target: selected),
                    ),
                  ],
                ),
              ),
              // === ROUTING CABLE SPACE (The Trench) ===
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  border: Border(
                    top: BorderSide(color: colors.outlineVariant, width: 4),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 12,
                      left: 16,
                      child: Text(
                        "ROUTING MATRIX",
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.16),
                          fontSize: 12,
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // === Routing Cables Overlay ===
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _trackScrollController,
                  _busScrollController,
                  _splitController,
                ]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RoutingPainter(
                      routing: routing,
                      stripKeys: _stripKeys,
                      selectedKey: selected == null
                          ? null
                          : _stripKeyOf(selected.routingNode),
                      overlayKey: _overlayKey,
                      activeColor: colors.primary,
                      inactiveColor: colors.outlineVariant,
                      plugColor: colors.surfaceContainerHighest,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Strip key for [node]. A sidechain input is drawn to the channel that owns
/// the keyed plugin; generator sidechains have no strip of their own.
String? _stripKeyOf(mixer_api.UiRoutingNode node) => switch (node) {
  mixer_api.UiRoutingNode_Track(:final field0) => 'track_$field0',
  mixer_api.UiRoutingNode_Bus(:final field0) => 'bus_$field0',
  mixer_api.UiRoutingNode_Master() => 'master',
  mixer_api.UiRoutingNode_PluginSidechain(:final field0) => switch (field0) {
    plugin_api.UiPluginTarget_TrackEffect(:final trackId) => 'track_$trackId',
    plugin_api.UiPluginTarget_BusEffect(:final busId) => 'bus_$busId',
    plugin_api.UiPluginTarget_MasterEffect() => 'master',
    plugin_api.UiPluginTarget_Generator() => null,
  },
};

class _RoutingPainter extends CustomPainter {
  final List<mixer_api.UiRoutingConnection> routing;
  final Map<String, GlobalKey> stripKeys;

  /// Strip key of the selected channel, whose cables are highlighted.
  final String? selectedKey;
  final GlobalKey overlayKey;
  final Color activeColor;
  final Color inactiveColor;
  final Color plugColor;

  _RoutingPainter({
    required this.routing,
    required this.stripKeys,
    required this.selectedKey,
    required this.overlayKey,
    required this.activeColor,
    required this.inactiveColor,
    required this.plugColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayContext = overlayKey.currentContext;
    if (overlayContext == null) return;
    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final activePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final plugPaint = Paint()
      ..color = plugColor
      ..style = PaintingStyle.fill;

    for (final conn in routing) {
      final srcStr = _stripKeyOf(conn.source);
      final dstStr = _stripKeyOf(conn.destination);

      if (srcStr == null || dstStr == null) continue;

      final srcKey = stripKeys[srcStr];
      final dstKey = stripKeys[dstStr];

      if (srcKey == null || dstKey == null) continue;

      final srcBox = srcKey.currentContext?.findRenderObject() as RenderBox?;
      final dstBox = dstKey.currentContext?.findRenderObject() as RenderBox?;

      if (srcBox == null || dstBox == null) continue;

      final srcPos = srcBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      final dstPos = dstBox.localToGlobal(Offset.zero, ancestor: overlayBox);

      // Start perfectly at the bottom center of the UI element
      final start = Offset(
        srcPos.dx + srcBox.size.width / 2,
        srcPos.dy + srcBox.size.height,
      );
      final end = Offset(
        dstPos.dx + dstBox.size.width / 2,
        dstPos.dy + dstBox.size.height,
      );

      // Draw little physical "plugs" extending down from the strip
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(start.dx, start.dy + 4),
          width: 8,
          height: 8,
        ),
        plugPaint,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(end.dx, end.dy + 4),
          width: 8,
          height: 8,
        ),
        plugPaint,
      );

      final isActive =
          selectedKey != null &&
          (srcStr == selectedKey || dstStr == selectedKey);

      final path = Path();
      // Start the actual curved wire from the tip of the plug
      final wireStart = Offset(start.dx, start.dy + 8);
      final wireEnd = Offset(end.dx, end.dy + 8);

      path.moveTo(wireStart.dx, wireStart.dy);

      // CURVE DOWNWARD: Add the drop value
      final distance = (wireEnd.dx - wireStart.dx).abs();
      // The wider the cable spans horizontally, the deeper it hangs!
      final drop = 50.0 + (distance * 0.15).clamp(0.0, 100.0);

      final controlPoint1 = Offset(wireStart.dx, wireStart.dy + drop); // + drop
      final controlPoint2 = Offset(wireEnd.dx, wireEnd.dy + drop); // + drop

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        wireEnd.dx,
        wireEnd.dy,
      );

      canvas.drawPath(path, isActive ? activePaint : inactivePaint);

      // Arrow indicator for signal direction
      if (isActive) {
        final arrowPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(wireEnd.dx, wireEnd.dy + 2), 4, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutingPainter oldDelegate) => true;
}
