import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/widgets/channel_toggle_button.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/db_level_meter.dart';
import 'package:karbeat/core/widgets/digidaw_plugin_widgets/widgets.dart';
import 'package:karbeat/core/widgets/fine_grained_input.dart';
import 'package:karbeat/features/mixer/view/bus_identity_actions.dart';
import 'package:karbeat/features/mixer/services/routing_labels.dart';
import 'package:karbeat/features/mixer/view/channel_output_chip.dart';
import 'package:karbeat/features/mixer/view/routing_dialog.dart';
import 'package:karbeat/features/mixer/view/sidechain_input_dialog.dart';
import 'package:karbeat/features/mixer/view/sidechain_target_picker.dart';
import 'package:karbeat/features/plugins/services/plugin_ui_launcher.dart';
import 'package:karbeat/features/plugins/widgets/plugin_browser_dialog.dart';
import 'package:karbeat/features/track/view/plugin_automation_parameter_dialog.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart' hide removeRouting;
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/src/rust/api/project.dart' show DawContext;
import 'package:multi_split_view/multi_split_view.dart';

class MixerScreen extends ConsumerStatefulWidget {
  const MixerScreen({super.key});

  @override
  ConsumerState<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends ConsumerState<MixerScreen> {
  // Track the currently selected channel ID (or -1 for Master)
  int? _selectedChannelId;
  bool _isSelectedBus = false;

  late final MultiSplitViewController _splitController;
  final Map<String, GlobalKey> _stripKeys = {};
  late final ScrollController _trackScrollController;
  late final ScrollController _busScrollController;

  // Key to track the exact coordinates of the drawing canvas
  final GlobalKey _overlayKey = GlobalKey();

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

    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   ref.read(mixerStateProvider.notifier).queryAllMixerChannels();
    //   await ref.read(mixerStateProvider.notifier).syncMixerState();
    // });
  }

  @override
  void dispose() {
    _trackScrollController.dispose();
    _busScrollController.dispose();
    super.dispose();
  }

  Widget _buildTracksArea(BuildContext context, Area area) {
    return Consumer(
      builder: (context, ref, _) {
        final projectState = ref.watch(projectProvider);
        final telemetry = ref.watch(mixerStateProvider);
        final mixerState = projectState.value?.mixer;
        final tracks = projectState.value?.tracks ?? const IMapConst({});

        if (mixerState == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final channelEntries = <_ChannelEntry>[];
        final sortedTrackIds = mixerState.channels.keys.toList()..sort();
        for (final trackId in sortedTrackIds) {
          final channel = mixerState.channels[trackId]!;
          final track = tracks[trackId];
          channelEntries.add(
            _ChannelEntry(
              id: trackId,
              name: track?.name ?? 'Track $trackId',
              channel: channel,
              magnitude: telemetry.trackMagnitudes[trackId] ?? 0.0,
              isMaster: false,
              color: track?.color.fromRGBorRGBAtoColor(),
            ),
          );
        }

        if (channelEntries.isEmpty) {
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
          itemCount: channelEntries.length,
          itemBuilder: (context, index) {
            final entry = channelEntries[index];
            return Container(
              key: _stripKeys.putIfAbsent(
                'track_${entry.id}',
                () => GlobalKey(),
              ),
              child: KeyedSubtree(
                key: ValueKey('mixer_track_${entry.id}'),
                child: ContextMenuWrapper(
                  title: 'Track ${entry.id}',
                  header: Column(children: [Text(entry.name)]),
                  actions: _routingActions(context, entry),
                  child: _ChannelStrip(
                    entry: entry,
                    footer: ChannelOutputChip(
                      source: _nodeOf(entry),
                      onTap: () => showRoutingDialog(
                        context: context,
                        source: _nodeOf(entry),
                      ),
                    ),
                    onVolumeChanged: (value) {
                      ref
                          .read(mixerStateProvider.notifier)
                          .setMixerChannelParam(
                            trackId: entry.id,
                            param: UiMixerChannelParams.volume(value),
                          );
                    },
                    onVolumeChangeStart: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .markParamTouched(entry.id, 'volume');
                    },
                    onVolumeChangeEnd: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .markParamReleased(entry.id, 'volume');
                    },
                    onPanChanged: (value) {
                      ref
                          .read(mixerStateProvider.notifier)
                          .setMixerChannelParam(
                            trackId: entry.id,
                            param: UiMixerChannelParams.pan(value),
                          );
                    },
                    onPanChangeStart: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .markParamTouched(entry.id, 'pan');
                    },
                    onPanChangeEnd: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .markParamReleased(entry.id, 'pan');
                    },
                    onMuteToggled: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .setMixerChannelParam(
                            trackId: entry.id,
                            param: UiMixerChannelParams.mute(
                              !entry.channel.mute,
                            ),
                          );
                    },
                    onSoloToggled: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .setMixerChannelParam(
                            trackId: entry.id,
                            param: UiMixerChannelParams.solo(
                              !entry.channel.solo,
                            ),
                          );
                    },
                    isSelected:
                        _selectedChannelId == entry.id &&
                        !_isSelectedBus &&
                        !entry.isMaster,
                    onTap: () {
                      setState(() {
                        _selectedChannelId = entry.id;
                        _isSelectedBus = false;
                      });
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBusesArea(BuildContext context, Area area) {
    return Consumer(
      builder: (context, ref, _) {
        final mixerState = ref.watch(projectProvider).value?.mixer;
        final telemetry = ref.watch(mixerStateProvider);

        if (mixerState == null) {
          return const SizedBox.shrink();
        }

        final busEntries = <_ChannelEntry>[];
        for (final bus in mixerState.buses.values) {
          busEntries.add(
            _ChannelEntry(
              id: bus.id,
              name: bus.name,
              channel: bus.channel,
              magnitude: telemetry.busMagnitudes[bus.id] ?? 0.0,
              isMaster: false,
              isBus: true,
              color: bus.color.fromRGBorRGBAtoColor(),
            ),
          );
        }

        return ListView.builder(
          controller: _busScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          itemCount: busEntries.length + 1,
          itemBuilder: (context, index) {
            final colors = Theme.of(context).colorScheme;
            // Last item: "Add Bus" ghost strip
            if (index == busEntries.length) {
              return GestureDetector(
                onTap: () async {
                  final busCount = busEntries.length + 1;
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

            final entry = busEntries[index];
            return Container(
              key: _stripKeys.putIfAbsent('bus_${entry.id}', () => GlobalKey()),
              child: KeyedSubtree(
                key: ValueKey('mixer_bus_${entry.id}'),
                child: ContextMenuWrapper(
                  title: 'Bus ${entry.id}',
                  header: Column(children: [Text(entry.name)]),
                  actions: [
                    ...busIdentityActions(
                      context: context,
                      ref: ref,
                      busId: entry.id,
                      name: entry.name,
                      color: entry.color ?? colors.primary,
                    ),
                    ..._routingActions(context, entry),
                    DawContextAction(
                      title: 'Delete Bus',
                      icon: Icons.delete,
                      isDestructive: true,
                      onTap: () {
                        ref
                            .read(mixerStateProvider.notifier)
                            .removeBus(busId: entry.id);
                      },
                    ),
                  ],
                  child: _ChannelStrip(
                    entry: entry,
                    footer: ChannelOutputChip(
                      source: _nodeOf(entry),
                      onTap: () => showRoutingDialog(
                        context: context,
                        source: _nodeOf(entry),
                      ),
                    ),
                    onVolumeChanged: (value) {
                      ref
                          .read(mixerStateProvider.notifier)
                          .setBusChannelParam(
                            busId: entry.id,
                            param: UiMixerChannelParams.volume(value),
                          );
                    },
                    onVolumeChangeStart: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .markParamTouched(entry.id, 'volume');
                    },
                    onVolumeChangeEnd: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .markParamReleased(entry.id, 'volume');
                    },
                    onPanChanged: (value) {
                      ref
                          .read(mixerStateProvider.notifier)
                          .setBusChannelParam(
                            busId: entry.id,
                            param: UiMixerChannelParams.pan(value),
                          );
                    },
                    onPanChangeStart: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .markParamTouched(entry.id, 'pan');
                    },
                    onPanChangeEnd: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .markParamReleased(entry.id, 'pan');
                    },
                    onMuteToggled: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .setBusChannelParam(
                            busId: entry.id,
                            param: UiMixerChannelParams.mute(
                              !entry.channel.mute,
                            ),
                          );
                    },
                    onSoloToggled: () {
                      ref
                          .read(mixerStateProvider.notifier)
                          .setBusChannelParam(
                            busId: entry.id,
                            param: UiMixerChannelParams.solo(
                              !entry.channel.solo,
                            ),
                          );
                    },
                    isSelected:
                        _selectedChannelId == entry.id && _isSelectedBus,
                    onTap: () {
                      setState(() {
                        _selectedChannelId = entry.id;
                        _isSelectedBus = true;
                      });
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  _ChannelEntry _masterEntry(UiMixerState mixerState, double magnitude) =>
      _ChannelEntry(
        id: -1,
        name: 'Master',
        channel: mixerState.masterBus,
        magnitude: magnitude,
        isMaster: true,
      );

  mixer_api.UiRoutingNode _nodeOf(_ChannelEntry entry) => entry.isMaster
      ? const mixer_api.UiRoutingNode.master()
      : entry.isBus
      ? mixer_api.UiRoutingNode.bus(entry.id)
      : mixer_api.UiRoutingNode.track(entry.id);

  /// The selected track or bus, which can key plugins on other channels.
  mixer_api.UiRoutingNode? get _selectedSource {
    final id = _selectedChannelId;
    if (id == null || (id == -1 && !_isSelectedBus)) return null;
    return _isSelectedBus
        ? mixer_api.UiRoutingNode.bus(id)
        : mixer_api.UiRoutingNode.track(id);
  }

  Future<void> _keySidechain(
    BuildContext context, {
    required mixer_api.UiRoutingNode source,
    mixer_api.UiRoutingNode? onlyChannel,
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

  /// Routing actions for a strip's context menu. The FL-style "sidechain the
  /// selected channel to this one" entry appears when another channel is
  /// selected.
  List<DawContextAction> _routingActions(
    BuildContext context,
    _ChannelEntry entry,
  ) {
    final store = ref.read(projectProvider).value;
    if (store == null) return [];
    final labels = RoutingLabels(mixer: store.mixer, tracks: store.tracks);
    final node = _nodeOf(entry);
    final output = store.mixer.routing
        .where((route) => route.source == node && !route.isSend)
        .firstOrNull;
    final selected = _selectedSource;
    final mixer = ref.read(mixerStateProvider.notifier);
    return [
      if (!entry.isMaster) ...[
        DawContextAction(
          title: 'Routing…',
          icon: Icons.account_tree,
          onTap: () => showRoutingDialog(context: context, source: node),
        ),
        if (output?.destination == const mixer_api.UiRoutingNode.master())
          DawContextAction(
            title: 'Unlink from master',
            icon: Icons.link_off,
            onTap: () => mixer.removeRouting(
              source: node,
              destination: const mixer_api.UiRoutingNode.master(),
              isSend: false,
            ),
          )
        else
          DawContextAction(
            title: 'Route to master',
            icon: Icons.link,
            onTap: () => mixer.updateRoutingCall(
              src: node,
              dest: const mixer_api.UiRoutingNode.master(),
              sendLvl: 1.0,
              isSend: false,
            ),
          ),
        DawContextAction(
          title: 'Sidechain this channel into…',
          icon: Icons.alt_route,
          onTap: () => _keySidechain(context, source: node),
        ),
      ],
      if (selected != null && selected != node)
        DawContextAction(
          title: 'Sidechain "${labels.channelName(selected)}" to this channel…',
          icon: Icons.call_merge,
          onTap: () =>
              _keySidechain(context, source: selected, onlyChannel: node),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final telemetry = ref.watch(mixerStateProvider);
    final mixerState = ref.watch(projectProvider).value?.mixer;

    if (mixerState == null) return const SizedBox.shrink();

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
                      key: _stripKeys.putIfAbsent('master', () => GlobalKey()),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      child: ContextMenuWrapper(
                        title: 'Master',
                        actions: _routingActions(
                          context,
                          _masterEntry(mixerState, telemetry.masterMagnitude),
                        ),
                        child: _ChannelStrip(
                          entry: _masterEntry(
                            mixerState,
                            telemetry.masterMagnitude,
                          ),
                          onVolumeChanged: (value) {
                            ref
                                .read(mixerStateProvider.notifier)
                                .setMasterBusParam(
                                  param: UiMixerChannelParams.volume(value),
                                );
                          },
                          onVolumeChangeStart: () {
                            ref
                                .read(mixerStateProvider.notifier)
                                .markParamTouched(4294967295, 'volume');
                          },
                          onVolumeChangeEnd: () {
                            ref
                                .read(mixerStateProvider.notifier)
                                .markParamReleased(4294967295, 'volume');
                          },
                          onPanChanged: (value) {
                            ref
                                .read(mixerStateProvider.notifier)
                                .setMasterBusParam(
                                  param: UiMixerChannelParams.pan(value),
                                );
                          },
                          onPanChangeStart: () {
                            ref
                                .read(mixerStateProvider.notifier)
                                .markParamTouched(4294967295, 'pan');
                          },
                          onPanChangeEnd: () {
                            ref
                                .read(mixerStateProvider.notifier)
                                .markParamReleased(4294967295, 'pan');
                          },
                          onMuteToggled: () {
                            ref
                                .read(mixerStateProvider.notifier)
                                .setMasterBusParam(
                                  param: UiMixerChannelParams.mute(
                                    !mixerState.masterBus.mute,
                                  ),
                                );
                          },
                          onSoloToggled: () {
                            ref
                                .read(mixerStateProvider.notifier)
                                .setMasterBusParam(
                                  param: UiMixerChannelParams.solo(
                                    !mixerState.masterBus.solo,
                                  ),
                                );
                          },
                          isSelected:
                              _selectedChannelId == -1 && !_isSelectedBus,
                          onTap: () {
                            setState(() {
                              _selectedChannelId = -1;
                              _isSelectedBus = false;
                            });
                          },
                        ),
                      ),
                    ),

                    // === Divider ===
                    Container(width: 1, color: colors.outlineVariant),

                    // === Effect Rack Panel ===
                    _buildEffectRackPanel(context, mixerState),
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
                      routing: mixerState.routing,
                      stripKeys: _stripKeys,
                      selectedChannelId: _selectedChannelId,
                      isSelectedBus: _isSelectedBus,
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

  Widget _buildEffectRackPanel(BuildContext ctx, UiMixerState mixerState) {
    final colors = Theme.of(ctx).colorScheme;
    if (_selectedChannelId == null) {
      return SizedBox(
        width: 250,
        child: Center(
          child: Text(
            'Select a channel to\nview effects',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ),
      );
    }

    final isMaster = _selectedChannelId == -1 && !_isSelectedBus;
    final channel = isMaster
        ? mixerState.masterBus
        : _isSelectedBus
        ? mixerState.buses[_selectedChannelId!]?.channel
        : mixerState.channels[_selectedChannelId!];

    if (channel == null) {
      return const SizedBox(width: 250);
    }

    final channelName = isMaster
        ? 'Master'
        : (_isSelectedBus
              ? 'Bus $_selectedChannelId'
              : 'Track $_selectedChannelId');
    final channelTarget = isMaster
        ? const mixer_api.UiMixerChannelTarget.master()
        : _isSelectedBus
        ? mixer_api.UiMixerChannelTarget.bus(_selectedChannelId!)
        : mixer_api.UiMixerChannelTarget.track(_selectedChannelId!);

    return Container(
      width: 250,
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
                    '$channelName Effects',
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
            child: channel.effects.isEmpty
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
                    itemCount: channel.effects.length,
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) {
                      ref
                          .read(mixerStateProvider.notifier)
                          .moveEffectOrder(
                            target: channelTarget,
                            effectId: channel.effects[oldIndex].id,
                            newPosition: newIndex,
                          );
                    },
                    itemBuilder: (context, index) {
                      final effect = channel.effects[index];
                      return Padding(
                        key: ValueKey(effect.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EffectRackItem(
                          effect: effect,
                          index: index,
                          channelTarget: channelTarget,
                          pluginTarget: _effectPluginTarget(effect.id),
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
              onPressed: () {
                _showEffectBrowser(context);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Effect'),
            ),
          ),
        ],
      ),
    );
  }

  /// Plugin target of an effect in the currently selected channel.
  plugin_api.UiPluginTarget _effectPluginTarget(int effectId) {
    final isMaster = _selectedChannelId == -1 && !_isSelectedBus;
    if (isMaster) return plugin_api.UiPluginTarget.masterEffect(effectId);
    if (_isSelectedBus) {
      return plugin_api.UiPluginTarget.busEffect(
        busId: _selectedChannelId!,
        effectId: effectId,
      );
    }
    return plugin_api.UiPluginTarget.trackEffect(
      trackId: _selectedChannelId!,
      effectId: effectId,
    );
  }

  void _showEffectBrowser(BuildContext context) async {
    final channelId = _selectedChannelId;
    final isBus = _isSelectedBus;
    if (channelId == null) {
      ref
          .read(notificationProvider.notifier)
          .warn(
            'No channel selected. Please select a channel before adding an effect.',
          );
      return;
    }

    await showPluginBrowserDialog(
      context: context,
      pluginType: KarbeatPluginType.effect,
      onAdd: (plugin) {
        if (channelId == -1 && !isBus) {
          return ref
              .read(mixerStateProvider.notifier)
              .addEffectToMasterBus(plugin.registryId);
        }
        if (isBus) {
          return ref
              .read(mixerStateProvider.notifier)
              .addEffectToBusChannel(channelId, plugin.registryId);
        }
        return ref
            .read(mixerStateProvider.notifier)
            .addEffectToMixerChannel(channelId, plugin.registryId);
      },
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
  final mixer_api.UiMixerChannelTarget channelTarget;
  final plugin_api.UiPluginTarget pluginTarget;

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

// =========================================================
// Data helper
// =========================================================

class _ChannelEntry {
  final int id;
  final String name;
  final UiMixerChannel channel;
  final double magnitude;
  final bool isMaster;
  final bool isBus;

  /// Color of the track or bus behind this strip; the theme accent when null.
  final Color? color;

  const _ChannelEntry({
    required this.id,
    required this.name,
    required this.channel,
    required this.magnitude,
    required this.isMaster,
    this.isBus = false,
    this.color,
  });
}

// =========================================================
// Channel Strip Widget
// =========================================================

class _ChannelStrip extends ConsumerStatefulWidget {
  final _ChannelEntry entry;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onVolumeChangeStart;
  final VoidCallback? onVolumeChangeEnd;
  final ValueChanged<double> onPanChanged;
  final VoidCallback? onPanChangeStart;
  final VoidCallback? onPanChangeEnd;
  final VoidCallback onMuteToggled;
  final VoidCallback onSoloToggled;
  final bool isSelected;
  final VoidCallback onTap;

  /// Shown under the mute and solo buttons, such as the output indicator.
  final Widget? footer;

  const _ChannelStrip({
    required this.entry,
    this.footer,
    required this.onVolumeChanged,
    this.onVolumeChangeStart,
    this.onVolumeChangeEnd,
    required this.onPanChanged,
    this.onPanChangeStart,
    this.onPanChangeEnd,
    required this.onMuteToggled,
    required this.onSoloToggled,
    required this.isSelected,
    required this.onTap,
  });

  @override
  _ChannelStripState createState() => _ChannelStripState();
}

class _ChannelStripState extends ConsumerState<_ChannelStrip> {
  List<ParameterSpecDTO>? _specs;

  DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;

  @override
  void initState() {
    super.initState();
    _loadSpecs();
  }

  Future<void> _loadSpecs() async {
    List<ParameterSpecDTO>? fetchedSpecs;
    try {
      if (widget.entry.isMaster) {
        fetchedSpecs = await getMasterChannelSpecs(ctx: _ctx);
      } else if (widget.entry.isBus) {
        fetchedSpecs = await getBusMixerChannelSpecs(
          ctx: _ctx,
          busId: widget.entry.id,
        );
      } else {
        fetchedSpecs = await getTrackMixerChannelSpecs(
          ctx: _ctx,
          trackId: widget.entry.id,
        );
      }
    } catch (e) {
      AppLogger.error("Failed to load channel specs: $e");
      ref.read(notificationProvider.notifier).error(e);
    }

    if (mounted) {
      setState(() {
        _specs = fetchedSpecs;
      });
    }
  }

  // Safe fallback spec generators just in case the Future hasn't resolved yet
  // (Prevents the UI from glitching or throwing layout errors during the microsecond load)
  ParameterSpecDTO _getVolumeSpec() {
    if (_specs != null) {
      return _specs!.firstWhere(
        (s) => s.id == 1,
        orElse: () => _defaultVolumeSpec(),
      );
    }
    return _defaultVolumeSpec();
  }

  ParameterSpecDTO _getPanSpec() {
    if (_specs != null) {
      return _specs!.firstWhere(
        (s) => s.id == 2,
        orElse: () => _defaultPanSpec(),
      );
    }
    return _defaultPanSpec();
  }

  ParameterSpecDTO _defaultVolumeSpec() => const ParameterSpecDTO(
    id: 1,
    name: 'Volume',
    group: 'MixerChannel',
    value: 0.0,
    min: -100.0,
    max: 6.0,
    defaultValue: 0.0,
    step: 0.1,
    valueType: ParameterValueTypeDTO.float,
    choices: [],
  );

  ParameterSpecDTO _defaultPanSpec() => const ParameterSpecDTO(
    id: 2,
    name: 'Pan',
    group: 'MixerChannel',
    value: 0.0,
    min: -1.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 0.01,
    valueType: ParameterValueTypeDTO.float,
    choices: [],
  );

  // Helper function to build the correct AutomationTarget instance based on track/bus/master
  AutomationTargetDto _getAutomationTarget({required bool isPan}) {
    final mixTarget = isPan
        ? const MixerChannelParamTargetDto.pan()
        : const MixerChannelParamTargetDto.volume();

    if (widget.entry.isMaster) {
      return AutomationTargetDto.master(
        MasterAutomationTargetDto.mixerChannel(mixTarget),
      );
    } else if (widget.entry.isBus) {
      return AutomationTargetDto.bus(
        busId: widget.entry.id,
        mixTarget: mixTarget,
      );
    } else {
      final trackTarget = TrackAutomationTargetDto.mixerChannel(mixTarget);
      return AutomationTargetDto.track(
        trackId: widget.entry.id,
        trackTarget: trackTarget,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final accentColor = entry.isMaster
        ? colors.tertiary
        : entry.color ?? colors.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 84,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: entry.isMaster
              ? colors.tertiaryContainer.withValues(alpha: 0.4)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isSelected
                ? accentColor
                : (entry.isMaster
                      ? colors.tertiary.withValues(alpha: 0.3)
                      : colors.outlineVariant),
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // === Channel Label ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
              ),
              child: Text(
                entry.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // === Pan Knob ===
            _PanKnob(
              value: entry.channel.pan,
              spec: _getPanSpec(),
              accentColor: accentColor,
              automationTarget: _getAutomationTarget(isPan: true),
              onChanged: widget.onPanChanged,
              onChangeStart: widget.onPanChangeStart,
              onChangeEnd: widget.onPanChangeEnd,
            ),

            const SizedBox(height: 12),

            // === Volume Fader ===
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    child: Semantics(
                      label: '${entry.name} output level',
                      value:
                          '${magnitudeToDb(entry.magnitude).toStringAsFixed(1)} dB',
                      child: DbLevelMeter(
                        magnitude: entry.magnitude,
                        showScale: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _VolumeFader(
                      value: entry.channel.volume,
                      spec: _getVolumeSpec(),
                      accentColor: accentColor,
                      onChanged: widget.onVolumeChanged,
                      onChangeStart: widget.onVolumeChangeStart,
                      onChangeEnd: widget.onVolumeChangeEnd,
                      automationTarget: _getAutomationTarget(isPan: false),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // === dB readout ===
            Text(
              _volumeToDb(entry.channel.volume),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 9),
            ),

            const SizedBox(height: 6),

            // === Mute / Solo ===
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChannelToggleButton(
                  label: 'M',
                  isActive: entry.channel.mute,
                  activeColor: colors.error,
                  onTap: widget.onMuteToggled,
                ),
                const SizedBox(width: 4),
                ChannelToggleButton(
                  label: 'S',
                  isActive: entry.channel.solo,
                  activeColor: colors.tertiary,
                  onTap: widget.onSoloToggled,
                ),
              ],
            ),

            if (widget.footer case final footer?) ...[
              const SizedBox(height: 6),
              footer,
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _volumeToDb(double volumeDb) {
    if (volumeDb <= -60.0) return '-∞ dB';
    return '${volumeDb.toStringAsFixed(1)} dB';
  }
}

// =========================================================
// Pan Knob
// =========================================================

class _PanKnob extends ConsumerWidget {
  final double value;
  final ParameterSpecDTO spec;
  final Color accentColor;
  final AutomationTargetDto automationTarget;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  const _PanKnob({
    required this.value,
    required this.spec,
    required this.accentColor,
    required this.onChanged,
    required this.automationTarget,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final label = value == 0
        ? 'C'
        : value < 0
        ? 'L${(-value * 100).round()}'
        : 'R${(value * 100).round()}';

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 9),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 56,
          height: 20,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: accentColor,
              inactiveTrackColor: colors.surfaceContainerHighest,
              thumbColor: accentColor,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: ParameterInteractionWrapper<double>(
              parameterName: spec.name,
              value: value,
              defaultValue: spec.defaultValue,
              min: spec.min,
              max: spec.max,
              step: spec.step == 0.0 ? 0.01 : spec.step,
              onChanged: onChanged,
              onAddAutomation: () async {
                AppLogger.info(
                  "Create automation for ${spec.name} (ID: ${spec.id})",
                );
                ref
                    .read(automationProvider.notifier)
                    .handleAddAutomationForTarget(
                      target: automationTarget,
                      label: spec.name,
                      initialValue: value,
                    );
              },
              onRemoveAutomation: () {
                AppLogger.info(
                  "remove automation for ${spec.name} (ID: ${spec.id})",
                );
                ref
                    .read(automationProvider.notifier)
                    .handleRemoveAutomationForTarget(target: automationTarget);
              },
              child: DigidawParameterKnob(
                value: value,
                min: spec.min,
                max: spec.max,
                defaultValue: spec.defaultValue,
                step: spec.step == 0.0 ? 0.01 : spec.step,
                diameter: 30.0, // Perfectly sized for the 72px channel strip
                activeColor: accentColor,
                inactiveColor: colors.surfaceContainerHighest,
                onChanged: onChanged,
                onChangeStart: onChangeStart != null
                    ? (_) => onChangeStart!()
                    : null,
                onChangeEnd: onChangeEnd != null ? (_) => onChangeEnd!() : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// Volume Fader
// =========================================================

class _VolumeFader extends ConsumerWidget {
  final double value;
  final ParameterSpecDTO spec;
  final Color accentColor;
  final AutomationTargetDto automationTarget;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  const _VolumeFader({
    required this.value,
    required this.spec,
    required this.accentColor,
    required this.automationTarget,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderWidth = constraints.maxHeight;

        // Ensure the visual slider stops at -60dB even if the internal `NEG_INFINITY` is lower
        final visualMin = spec.min < -100.0 ? -100.0 : spec.min;

        return RotatedBox(
          quarterTurns: 3,
          child: ParameterInteractionWrapper<double>(
            parameterName: spec.name,
            value: value,
            defaultValue: spec.defaultValue,
            min: visualMin,
            max: spec.max,
            step: spec.step == 0.0 ? 0.1 : spec.step,
            onChanged: onChanged,
            onAddAutomation: () async {
              AppLogger.info(
                "Create automation for ${spec.name} (ID: ${spec.id})",
              );
              ref
                  .read(automationProvider.notifier)
                  .handleAddAutomationForTarget(
                    target: automationTarget,
                    label: spec.name,
                    initialValue: value,
                  );
            },
            onRemoveAutomation: () async {
              AppLogger.info(
                "Remove automation for ${spec.name} (ID: ${spec.id})",
              );
              ref
                  .read(automationProvider.notifier)
                  .handleRemoveAutomationForTarget(target: automationTarget);
            },
            child: SizedBox(
              width: sliderWidth,
              height: constraints.maxWidth,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  activeTrackColor: accentColor,
                  inactiveTrackColor: colors.surfaceContainerHighest,
                  thumbColor: accentColor,
                  overlayColor: accentColor.withValues(alpha: 0.15),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: DigidawParameterSlider(
                  color: accentColor,
                  slider: Slider(
                    value: value.clamp(visualMin, spec.max),
                    min: visualMin,
                    max: spec.max,
                    onChanged: onChanged,
                    allowedInteraction: SliderInteraction.slideThumb,
                    onChangeStart: onChangeStart != null
                        ? (_) => onChangeStart!()
                        : null,
                    onChangeEnd: onChangeEnd != null
                        ? (_) => onChangeEnd!()
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// Small Toggle Button (Mute / Solo)
// =========================================================

class _RoutingPainter extends CustomPainter {
  final List<mixer_api.UiRoutingConnection> routing;
  final Map<String, GlobalKey> stripKeys;
  final int? selectedChannelId;
  final bool isSelectedBus;
  final GlobalKey overlayKey;
  final Color activeColor;
  final Color inactiveColor;
  final Color plugColor;

  _RoutingPainter({
    required this.routing,
    required this.stripKeys,
    required this.selectedChannelId,
    required this.isSelectedBus,
    required this.overlayKey,
    required this.activeColor,
    required this.inactiveColor,
    required this.plugColor,
  });

  /// Strip key for [node]. A sidechain input is drawn to the channel that
  /// owns the keyed plugin; generator sidechains have no strip of their own.
  String? _getNodeKeyString(mixer_api.UiRoutingNode node) => switch (node) {
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
      final srcStr = _getNodeKeyString(conn.source);
      final dstStr = _getNodeKeyString(conn.destination);

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

      bool isActive = false;
      if (selectedChannelId != null) {
        final selectedStr = selectedChannelId == -1
            ? 'master'
            : (isSelectedBus
                  ? 'bus_$selectedChannelId'
                  : 'track_$selectedChannelId');
        if (srcStr == selectedStr || dstStr == selectedStr) {
          isActive = true;
        }
      }

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
