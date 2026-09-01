import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/db_level_meter.dart';
import 'package:karbeat/core/widgets/digidaw_plugin_widgets/widgets.dart';
import 'package:karbeat/core/widgets/fine_grained_input.dart';
import 'package:karbeat/features/plugins/plugin_registry.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart' hide removeRouting;
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
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
          final trackName = tracks[trackId]?.name ?? 'Track $trackId';
          channelEntries.add(
            _ChannelEntry(
              id: trackId,
              name: trackName,
              channel: channel,
              magnitude: telemetry.trackMagnitudes[trackId] ?? 0.0,
              isMaster: false,
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
                  actions: [
                    DawContextAction(
                      title: 'Route to node...',
                      onTap: () {
                        _showRoutingDialog(context, entry);
                      },
                    ),
                  ],
                  child: _ChannelStrip(
                    entry: entry,
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
                    DawContextAction(
                      title: 'Route to node...',
                      icon: Icons.account_tree,
                      onTap: () {
                        _showRoutingDialog(context, entry);
                      },
                    ),
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

  void _showRoutingDialog(BuildContext context, _ChannelEntry entry) {
    final sourceNode = entry.isBus
        ? mixer_api.UiRoutingNode.bus(entry.id)
        : mixer_api.UiRoutingNode.track(entry.id);

    showDialog(
      context: context,
      builder: (ctx) =>
          _RoutingDialog(sourceNode: sourceNode, sourceName: entry.name),
    );
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      child: _ChannelStrip(
                        entry: _ChannelEntry(
                          id: -1,
                          name: 'Master',
                          channel: mixerState.masterBus,
                          magnitude: telemetry.masterMagnitude,
                          isMaster: true,
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
                        isSelected: _selectedChannelId == -1 && !_isSelectedBus,
                        onTap: () {
                          setState(() {
                            _selectedChannelId = -1;
                            _isSelectedBus = false;
                          });
                        },
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
                Text(
                  '$channelName Effects',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.transparent,
                    fontSize: 14,
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
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: channel.effects.length,
                    itemBuilder: (context, index) {
                      final effect = channel.effects[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: colors.surfaceContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(color: colors.outlineVariant),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              effect.name,
                              style: TextStyle(color: colors.onSurface),
                            ),
                            subtitle: Text(
                              'ID: ${effect.id}',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            trailing: Icon(
                              Icons.settings,
                              color: colors.onSurfaceVariant,
                              size: 16,
                            ),
                            onTap: () async {
                              try {
                                final target = isMaster
                                    ? plugin_api.UiPluginTarget.masterEffect(
                                        effect.id,
                                      )
                                    : _isSelectedBus
                                    ? plugin_api.UiPluginTarget.busEffect(
                                        busId: _selectedChannelId!,
                                        effectId: effect.id,
                                      )
                                    : plugin_api.UiPluginTarget.trackEffect(
                                        trackId: _selectedChannelId!,
                                        effectId: effect.id,
                                      );
                                final availableEffects = await ref
                                    .read(audioPluginProvider.notifier)
                                    .getAvailableEffects();
                                final registryId = availableEffects
                                    .firstWhere(
                                      (p) => p.id == effect.registryId,
                                    )
                                    .id;

                                final screen = PluginRegistryFlutter.getScreen(
                                  registryId: registryId,
                                  instanceId: effect.id,
                                  target: target,
                                );
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => screen,
                                  ),
                                );
                              } catch (_) {
                                // Feedback for effects that don't have a UI yet
                                if (!context.mounted) return;
                                ref
                                    .read(notificationProvider.notifier)
                                    .warn(
                                      '${effect.name} UI is not implemented yet.',
                                      duration: const Duration(seconds: 2),
                                    );
                              }
                            },
                          ),
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

  void _showEffectBrowser(BuildContext context) async {
    final availablePlugins = await ref
        .read(audioPluginProvider.notifier)
        .getAvailableEffects();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Generator Browser"),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 24),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category header: Karbeat Native
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.extension,
                      size: 16,
                      color: Theme.of(ctx).colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(ctx).colorScheme.tertiary,
                        ),
                      ),
                      child: Text(
                        "Karbeat Native",
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onTertiaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Plugin list
              if (availablePlugins.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Text(
                    "No effects found",
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...availablePlugins.map(
                  (plugin) => _buildEffectBrowserItem(ctx, plugin),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectBrowserItem(BuildContext ctx, UiPluginInfo plugin) {
    final colors = Theme.of(ctx).colorScheme;
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        if (plugin.pluginType != KarbeatPluginType.effect) {
          ref
              .read(notificationProvider.notifier)
              .warn('Only effects can be added from the mixer panel for now.');
          return;
        }
        if (_selectedChannelId == null) {
          ref
              .read(notificationProvider.notifier)
              .warn(
                'No channel selected. Please select a channel before adding an effect.',
              );
          return;
        }

        if (_selectedChannelId == -1 && !_isSelectedBus) {
          ref.read(mixerStateProvider.notifier).addEffectToMasterBus(plugin.id);
          return;
        }

        if (_isSelectedBus) {
          ref
              .read(mixerStateProvider.notifier)
              .addEffectToBusChannel(_selectedChannelId!, plugin.id);
        } else {
          ref
              .read(mixerStateProvider.notifier)
              .addEffectToMixerChannel(_selectedChannelId!, plugin.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.piano, color: colors.tertiary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plugin.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Karbeat Native",
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  const _ChannelEntry({
    required this.id,
    required this.name,
    required this.channel,
    required this.magnitude,
    required this.isMaster,
    this.isBus = false,
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

  const _ChannelStrip({
    required this.entry,
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
    final accentColor = entry.isMaster ? colors.tertiary : colors.primary;

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
                _ToggleButton(
                  label: 'M',
                  isActive: entry.channel.mute,
                  activeColor: colors.error,
                  onTap: widget.onMuteToggled,
                ),
                const SizedBox(width: 4),
                _ToggleButton(
                  label: 'S',
                  isActive: entry.channel.solo,
                  activeColor: colors.tertiary,
                  onTap: widget.onSoloToggled,
                ),
              ],
            ),

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
                      min: spec.min,
                      max: spec.max,
                      defaultValue: spec.defaultValue,
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
                    min: spec.min,
                    max: spec.max,
                    defaultValue: spec.defaultValue,
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

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeForeground =
        ThemeData.estimateBrightnessForColor(activeColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 22,
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.85)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? activeColor : colors.outlineVariant,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? activeForeground : colors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

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

  String? _getNodeKeyString(mixer_api.UiRoutingNode node) {
    if (node is mixer_api.UiRoutingNode_Track) return 'track_${node.field0}';
    if (node is mixer_api.UiRoutingNode_Bus) return 'bus_${node.field0}';
    if (node is mixer_api.UiRoutingNode_Master) return 'master';
    return null;
  }

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

// Place this at the bottom of your file with _RoutingPainter
class _RoutingDialog extends ConsumerStatefulWidget {
  final mixer_api.UiRoutingNode sourceNode;
  final String sourceName;

  const _RoutingDialog({required this.sourceNode, required this.sourceName});

  @override
  _RoutingDialogState createState() => _RoutingDialogState();
}

class _RoutingDialogState extends ConsumerState<_RoutingDialog> {
  late List<mixer_api.UiRoutingConnection> currentRoutes;
  mixer_api.UiRoutingConnection? mainRoute;
  List<mixer_api.UiRoutingConnection> sends = [];

  // Local state for smooth slider dragging before pushing to backend
  final Map<String, double> _localSendLevels = {};

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    currentRoutes = ref
        .read(mixerStateProvider.notifier)
        .getMixerChannelDest(source: widget.sourceNode);
    mainRoute = currentRoutes.where((r) => !r.isSend).firstOrNull;
    sends = currentRoutes.where((r) => r.isSend).toList();

    for (final s in sends) {
      final key = _getNodeKeyStr(s.destination);
      if (key != null) {
        _localSendLevels[key] = s.sendLevel;
      }
    }
  }

  String? _getNodeKeyStr(mixer_api.UiRoutingNode node) {
    if (node is mixer_api.UiRoutingNode_Track) return 'track_${node.field0}';
    if (node is mixer_api.UiRoutingNode_Bus) return 'bus_${node.field0}';
    if (node is mixer_api.UiRoutingNode_Master) return 'master';
    return null;
  }

  bool _isSameNode(mixer_api.UiRoutingNode a, mixer_api.UiRoutingNode b) {
    return _getNodeKeyStr(a) == _getNodeKeyStr(b);
  }

  /// Result errors are emitted by [MixerNotifier] through notificationProvider.
  void _handleRoutingResult(Result<void> result) {
    // Awaiting the result still sequences optimistic routing updates. The
    // global notification observer owns all user-facing failure feedback.
  }

  Future<void> _setMainOutput(mixer_api.UiRoutingNode newDest) async {
    final result = await ref
        .read(mixerStateProvider.notifier)
        .updateRoutingCall(
          src: widget.sourceNode,
          dest: newDest,
          sendLvl: 1.0,
          isSend: false,
        );

    _handleRoutingResult(result);

    if (mounted) {
      setState(() {
        _refreshData();
      });
    }
  }

  Future<void> _toggleSend(mixer_api.UiRoutingNode dest, bool enable) async {
    if (enable) {
      final result = await ref
          .read(mixerStateProvider.notifier)
          .updateRoutingCall(
            src: widget.sourceNode,
            dest: dest,
            sendLvl: 0.5, // Default start level (50%)
            isSend: true,
          );
      _handleRoutingResult(result);
    } else {
      // We still use removeRouting here because updateRoutingCall only UPSERTS
      final result = await ref
          .read(mixerStateProvider.notifier)
          .removeRouting(
            source: widget.sourceNode,
            destination: dest,
            isSend: true,
          );
      _handleRoutingResult(result);
    }

    if (mounted) {
      setState(() {
        _refreshData();
      });
    }
  }

  Future<void> _updateSendLevel(
    mixer_api.UiRoutingNode dest,
    double level,
  ) async {
    final result = await ref
        .read(mixerStateProvider.notifier)
        .updateRoutingCall(
          src: widget.sourceNode,
          dest: dest,
          sendLvl: level,
          isSend: true,
        );

    _handleRoutingResult(result);

    if (mounted) {
      setState(() {
        _refreshData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mixerState = ref.watch(projectProvider).value?.mixer;
    if (mixerState == null) return const SizedBox.shrink();
    // 1. Gather Valid Main Outputs (Master + All Buses except self)
    final List<MapEntry<String, mixer_api.UiRoutingNode>> availableMainOutputs =
        [const MapEntry("Master", mixer_api.UiRoutingNode.master())];
    for (final bus in mixerState.buses.values) {
      final node = mixer_api.UiRoutingNode.bus(bus.id);
      if (!_isSameNode(widget.sourceNode, node)) {
        availableMainOutputs.add(MapEntry(bus.name, node));
      }
    }

    // 2. Gather Valid Sends (All Buses except self AND except current Main Output)
    final List<MapEntry<String, mixer_api.UiRoutingNode>> availableSends = [];
    for (final bus in mixerState.buses.values) {
      final node = mixer_api.UiRoutingNode.bus(bus.id);
      if (!_isSameNode(widget.sourceNode, node) &&
          (mainRoute == null || !_isSameNode(mainRoute!.destination, node))) {
        availableSends.add(MapEntry(bus.name, node));
      }
    }

    return AlertDialog(
      title: Text("Routing: ${widget.sourceName}"),
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- MAIN OUTPUT ---
            Text(
              "MAIN OUTPUT (Pre-Fader)",
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: mainRoute != null
                      ? _getNodeKeyStr(mainRoute!.destination)
                      : null,
                  isExpanded: true,
                  dropdownColor: colors.surfaceContainerHigh,
                  style: TextStyle(color: colors.primary),
                  items: availableMainOutputs.map((entry) {
                    return DropdownMenuItem<String>(
                      value: _getNodeKeyStr(entry.value),
                      child: Text(entry.key),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final node = availableMainOutputs
                        .firstWhere((e) => _getNodeKeyStr(e.value) == val)
                        .value;
                    _setMainOutput(node);
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- SENDS ---
            Text(
              "SENDS (Post-Fader)",
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (availableSends.isEmpty)
              Text(
                "No available buses to send to.",
                style: TextStyle(
                  color: colors.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ...availableSends.map((entry) {
              final destKey = _getNodeKeyStr(entry.value)!;
              final existingSend = sends
                  .where((s) => _isSameNode(s.destination, entry.value))
                  .firstOrNull;
              final isEnabled = existingSend != null;
              final level = _localSendLevels[destKey] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Switch(
                      value: isEnabled,
                      activeThumbColor: colors.primary,
                      onChanged: (v) => _toggleSend(entry.value, v),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: isEnabled
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: colors.primary,
                          inactiveTrackColor: colors.surfaceContainerHighest,
                          thumbColor: colors.primary,
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: level.clamp(0.0, 1.0),
                          onChanged: isEnabled
                              ? (v) {
                                  setState(() {
                                    _localSendLevels[destKey] = v;
                                  });
                                }
                              : null,
                          onChangeEnd: isEnabled
                              ? (v) => _updateSendLevel(entry.value, v)
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        "${(level * 100).toInt()}%",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isEnabled
                              ? colors.onSurfaceVariant
                              : colors.outline,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
