import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/components/context_menu.dart';
import 'package:karbeat/features/components/fine_grained_input.dart';
import 'package:karbeat/features/audio_plugins/effects/effect_registry.dart';
import 'package:karbeat/services/mixer_service.dart';
import 'package:karbeat/src/rust/api/mixer.dart' hide removeRouting;
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/state/app_state.dart';
import 'package:karbeat/utils/logger.dart';
import 'package:karbeat/utils/result_type.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = ref.read(globalStateProvider);
      await state.syncMixerState();
    });
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
        final mixerState = ref.watch(
          globalStateProvider.select((s) => s.mixerState),
        );
        final tracks = ref.watch(globalStateProvider.select((s) => s.tracks));
        final state = ref.read(globalStateProvider);

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
              isMaster: false,
            ),
          );
        }

        if (channelEntries.isEmpty) {
          return Center(
            child: Text(
              'No channels',
              style: TextStyle(
                color: Colors.grey.shade600,
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
                        _showRoutingDialog(context, entry, mixerState, state);
                      },
                    ),
                  ],
                  child: _ChannelStrip(
                    entry: entry,
                    onVolumeChanged: (value) {
                      state.setMixerChannelParam(
                        trackId: entry.id,
                        param: UiMixerChannelParams.volume(value),
                      );
                    },
                    onVolumeChangeStart: () {
                      state.markParamTouched(entry.id, 'volume');
                    },
                    onVolumeChangeEnd: () {
                      state.markParamReleased(entry.id, 'volume');
                    },
                    onPanChanged: (value) {
                      state.setMixerChannelParam(
                        trackId: entry.id,
                        param: UiMixerChannelParams.pan(value),
                      );
                    },
                    onPanChangeStart: () {
                      state.markParamTouched(entry.id, 'pan');
                    },
                    onPanChangeEnd: () {
                      state.markParamReleased(entry.id, 'pan');
                    },
                    onMuteToggled: () {
                      state.setMixerChannelParam(
                        trackId: entry.id,
                        param: UiMixerChannelParams.mute(!entry.channel.mute),
                      );
                    },
                    onSoloToggled: () {
                      state.setMixerChannelParam(
                        trackId: entry.id,
                        param: UiMixerChannelParams.solo(!entry.channel.solo),
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
        final mixerState = ref.watch(
          globalStateProvider.select((s) => s.mixerState),
        );
        final state = ref.read(globalStateProvider);

        final busEntries = <_ChannelEntry>[];
        for (final bus in mixerState.buses.values) {
          busEntries.add(
            _ChannelEntry(
              id: bus.id,
              name: bus.name,
              channel: bus.channel,
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
            // Last item: "Add Bus" ghost strip
            if (index == busEntries.length) {
              return GestureDetector(
                onTap: () async {
                  final busCount = busEntries.length + 1;
                  await state.createNewBusChannel(name: "Bus $busCount");
                },
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: Colors.white.withValues(alpha: 0.25),
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add Bus',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
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
                        _showRoutingDialog(context, entry, mixerState, state);
                      },
                    ),
                    DawContextAction(
                      title: 'Delete Bus',
                      icon: Icons.delete,
                      isDestructive: true,
                      onTap: () {
                        removeBus(state, busId: entry.id);
                      },
                    ),
                  ],
                  child: _ChannelStrip(
                    entry: entry,
                    onVolumeChanged: (value) {
                      state.setBusChannelParam(
                        busId: entry.id,
                        param: UiMixerChannelParams.volume(value),
                      );
                    },
                    onVolumeChangeStart: () {
                      state.markParamTouched(entry.id, 'volume');
                    },
                    onVolumeChangeEnd: () {
                      state.markParamReleased(entry.id, 'volume');
                    },
                    onPanChanged: (value) {
                      state.setBusChannelParam(
                        busId: entry.id,
                        param: UiMixerChannelParams.pan(value),
                      );
                    },
                    onPanChangeStart: () {
                      state.markParamTouched(entry.id, 'pan');
                    },
                    onPanChangeEnd: () {
                      state.markParamReleased(entry.id, 'pan');
                    },
                    onMuteToggled: () {
                      state.setBusChannelParam(
                        busId: entry.id,
                        param: UiMixerChannelParams.mute(!entry.channel.mute),
                      );
                    },
                    onSoloToggled: () {
                      state.setBusChannelParam(
                        busId: entry.id,
                        param: UiMixerChannelParams.solo(!entry.channel.solo),
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

  void _showRoutingDialog(
    BuildContext context,
    _ChannelEntry entry,
    UiMixerState mixerState,
    GlobalAppState state, // Using dynamic or your GlobalAppState type
  ) {
    final sourceNode = entry.isBus
        ? mixer_api.UiRoutingNode.bus(entry.id)
        : mixer_api.UiRoutingNode.track(entry.id);

    showDialog(
      context: context,
      builder: (ctx) => _RoutingDialog(
        sourceNode: sourceNode,
        sourceName: entry.name,
        state: state,
        mixerState: mixerState,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mixerState = ref.watch(
      globalStateProvider.select((s) => s.mixerState),
    );
    final state = ref.read(globalStateProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
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
                            color: Colors.white10,
                            highlightedColor: Colors.white70,
                          ),
                        ),
                        child: MultiSplitView(controller: _splitController),
                      ),
                    ),

                    // === Divider ===
                    Container(width: 1, color: Colors.white10),

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
                          isMaster: true,
                        ),
                        onVolumeChanged: (value) {
                          state.setMasterBusParam(
                            param: UiMixerChannelParams.volume(value),
                          );
                        },
                        onVolumeChangeStart: () {
                          state.markParamTouched(4294967295, 'volume');
                        },
                        onVolumeChangeEnd: () {
                          state.markParamReleased(4294967295, 'volume');
                        },
                        onPanChanged: (value) {
                          state.setMasterBusParam(
                            param: UiMixerChannelParams.pan(value),
                          );
                        },
                        onPanChangeStart: () {
                          state.markParamTouched(4294967295, 'pan');
                        },
                        onPanChangeEnd: () {
                          state.markParamReleased(4294967295, 'pan');
                        },
                        onMuteToggled: () {
                          state.setMasterBusParam(
                            param: UiMixerChannelParams.mute(
                              !mixerState.masterBus.mute,
                            ),
                          );
                        },
                        onSoloToggled: () {
                          state.setMasterBusParam(
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
                    Container(width: 1, color: Colors.white10),

                    // === Effect Rack Panel ===
                    _buildEffectRackPanel(context, mixerState),
                  ],
                ),
              ),
              // === ROUTING CABLE SPACE (The Trench) ===
              Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF0C0C0F), // Darker trench
                  border: Border(
                    top: BorderSide(color: Colors.black, width: 4),
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
                          color: Colors.white.withAlpha(40),
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
    if (_selectedChannelId == null) {
      return const SizedBox(
        width: 250,
        child: Center(
          child: Text(
            'Select a channel to\nview effects',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
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
      color: Colors.grey.shade900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.black26,
            child: Row(
              children: [
                const Icon(Icons.blur_on, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$channelName Effects',
                  style: const TextStyle(
                    color: Colors.white,
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
                ? const Center(
                    child: Text(
                      'No effects',
                      style: TextStyle(
                        color: Colors.white38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: channel.effects.length,
                    itemBuilder: (context, index) {
                      final effect = channel.effects[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withAlpha(20)),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            effect.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'ID: ${effect.id}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: const Icon(
                            Icons.settings,
                            color: Colors.white54,
                            size: 16,
                          ),
                          onTap: () {
                            try {
                              final target = isMaster
                                  ? const plugin_api.UiEffectTarget.master()
                                  : _isSelectedBus
                                  ? plugin_api.UiEffectTarget.bus(
                                      _selectedChannelId!,
                                    )
                                  : plugin_api.UiEffectTarget.track(
                                      _selectedChannelId!,
                                    );

                              final availableEffects = ref
                                  .read(globalStateProvider)
                                  .availableEffects;
                              final registryId = availableEffects
                                  .firstWhere((p) => p.id == effect.registryId)
                                  .id;

                              final screen = EffectRegistry.getScreen(
                                registryId: registryId,
                                instanceId: effect.id,
                                target: target,
                              );

                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => screen),
                              );
                            } catch (_) {
                              // Feedback for effects that don't have a UI yet
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${effect.name} UI is not implemented yet.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
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
                backgroundColor: Colors.white.withAlpha(20),
                foregroundColor: Colors.white,
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

  void _showEffectBrowser(BuildContext context) {
    final availablePlugins = ref.read(globalStateProvider).availableEffects;

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
                      color: Colors.deepOrangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrangeAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.deepOrangeAccent.withAlpha(80),
                        ),
                      ),
                      child: const Text(
                        "Karbeat Native",
                        style: TextStyle(
                          color: Colors.deepOrangeAccent,
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    "No effects found",
                    style: TextStyle(color: Colors.grey),
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
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        if (plugin.pluginType != KarbeatPluginType.effect) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'Only effects can be added from the mixer panel for now.',
              ),
            ),
          );
          return;
        }
        if (_selectedChannelId == null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'No channel selected. Please select a channel before adding an effect.',
              ),
            ),
          );
          return;
        }

        if (_selectedChannelId == -1 && !_isSelectedBus) {
          ref.read(globalStateProvider).addEffectToMasterBus(plugin.id);
          return;
        }

        if (_isSelectedBus) {
          ref
              .read(globalStateProvider)
              .addEffectToBusChannel(_selectedChannelId!, plugin.id);
        } else {
          ref
              .read(globalStateProvider)
              .addEffectToMixerChannel(_selectedChannelId!, plugin.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.piano, color: Colors.orangeAccent, size: 20),
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
                  const Text(
                    "Karbeat Native",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
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
  final bool isMaster;
  final bool isBus;

  const _ChannelEntry({
    required this.id,
    required this.name,
    required this.channel,
    required this.isMaster,
    this.isBus = false,
  });
}

// =========================================================
// Channel Strip Widget
// =========================================================

class _ChannelStrip extends StatefulWidget {
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
  State<_ChannelStrip> createState() => _ChannelStripState();
}

class _ChannelStripState extends State<_ChannelStrip> {
  List<ParameterSpecDTO>? _specs;

  @override
  void initState() {
    super.initState();
    _loadSpecs();
  }

  Future<void> _loadSpecs() async {
    List<ParameterSpecDTO>? fetchedSpecs;
    try {
      if (widget.entry.isMaster) {
        fetchedSpecs = await getMasterChannelSpecs();
      } else if (widget.entry.isBus) {
        fetchedSpecs = await getBusMixerChannelSpecs(busId: widget.entry.id);
      } else {
        fetchedSpecs = await getTrackMixerChannelSpecs(
          trackId: widget.entry.id,
        );
      }
    } catch (e) {
      debugPrint("Failed to load channel specs: $e");
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

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final accentColor = entry.isMaster
        ? const Color(0xFFFFD700)
        : const Color(0xFF00E5FF);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: entry.isMaster
              ? const Color(0xFF2A2040)
              : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isSelected
                ? accentColor
                : (entry.isMaster
                      ? Colors.amber.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06)),
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
              spec: _getPanSpec(), // Pass the bound FFI Spec
              accentColor: accentColor,
              onChanged: widget.onPanChanged,
              onChangeStart: widget.onPanChangeStart,
              onChangeEnd: widget.onPanChangeEnd,
            ),

            const SizedBox(height: 4),

            // === Volume Fader ===
            Expanded(
              child: _VolumeFader(
                value: entry.channel.volume,
                spec: _getVolumeSpec(), // Pass the bound FFI Spec
                accentColor: accentColor,
                onChanged: widget.onVolumeChanged,
                onChangeStart: widget.onVolumeChangeStart,
                onChangeEnd: widget.onVolumeChangeEnd,
              ),
            ),

            const SizedBox(height: 4),

            // === dB readout ===
            Text(
              _volumeToDb(entry.channel.volume),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),

            const SizedBox(height: 6),

            // === Mute / Solo ===
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ToggleButton(
                  label: 'M',
                  isActive: entry.channel.mute,
                  activeColor: Colors.redAccent,
                  onTap: widget.onMuteToggled,
                ),
                const SizedBox(width: 4),
                _ToggleButton(
                  label: 'S',
                  isActive: entry.channel.solo,
                  activeColor: Colors.amber,
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

class _PanKnob extends StatelessWidget {
  final double value;
  final ParameterSpecDTO spec; // Injected FFI Spec
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  const _PanKnob({
    required this.value,
    required this.spec,
    required this.accentColor,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final label = value == 0
        ? 'C'
        : value < 0
        ? 'L${(-value * 100).round()}'
        : 'R${(value * 100).round()}';

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 9,
            fontFamily: 'monospace',
          ),
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
              inactiveTrackColor: Colors.white12,
              thumbColor: accentColor,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: ParameterInteractionWrapper<double>(
              parameterName: spec.name,
              value: value,
              defaultValue: spec.defaultValue,
              min: spec.min,
              max: spec.max,
              step: spec.step == 0.0 ? 0.01 : spec.step, // Safe fallback step
              onChanged: onChanged,
              onAddAutomation: () {
                AppLogger.info(
                  "Create automation for ${spec.name} (ID: ${spec.id})",
                );
                // TODO: Dispatch to state to create the lane
              },
              child: Slider(
                value: value,
                min: spec.min,
                max: spec.max,
                onChanged: onChanged,
                allowedInteraction: SliderInteraction.slideOnly,
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

class _VolumeFader extends StatelessWidget {
  final double value;
  final ParameterSpecDTO spec;
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  const _VolumeFader({
    required this.value,
    required this.spec,
    required this.accentColor,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderWidth = constraints.maxHeight;

        // Ensure the visual slider stops at -60dB even if the internal `NEG_INFINITY` is lower
        final visualMin = spec.min < -60.0 ? -60.0 : spec.min;

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
            onAddAutomation: () {
              debugPrint("Create automation for ${spec.name} (ID: ${spec.id})");
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
                  inactiveTrackColor: Colors.white10,
                  thumbColor: accentColor,
                  overlayColor: accentColor.withValues(alpha: 0.15),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 22,
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive
                ? activeColor
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black87 : Colors.grey.shade500,
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

  _RoutingPainter({
    required this.routing,
    required this.stripKeys,
    required this.selectedChannelId,
    required this.isSelectedBus,
    required this.overlayKey,
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
      ..color = Colors.cyanAccent.withAlpha(200)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final inactivePaint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final plugPaint = Paint()
      ..color = Colors.grey.shade800
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
          ..color = Colors.cyanAccent.withAlpha(200)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(wireEnd.dx, wireEnd.dy + 2), 4, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutingPainter oldDelegate) => true;
}

// Place this at the bottom of your file with _RoutingPainter
class _RoutingDialog extends StatefulWidget {
  final mixer_api.UiRoutingNode sourceNode;
  final String sourceName;
  final GlobalAppState state;
  final mixer_api.UiMixerState mixerState;

  const _RoutingDialog({
    required this.sourceNode,
    required this.sourceName,
    required this.state,
    required this.mixerState,
  });

  @override
  State<_RoutingDialog> createState() => _RoutingDialogState();
}

class _RoutingDialogState extends State<_RoutingDialog> {
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
    currentRoutes = getMixerChannelDest(
      widget.state,
      source: widget.sourceNode,
    );
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

  /// Helper to safely handle FFI results and show snackbars on cycle errors
  void _handleRoutingResult(Result<void> result) {
    if (result.isErr() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((result as Error<void>).toErrorMessage()),
          backgroundColor: Colors.redAccent.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _setMainOutput(mixer_api.UiRoutingNode newDest) async {
    final result = await updateRoutingCall(
      widget.state,
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
      final result = await updateRoutingCall(
        widget.state,
        src: widget.sourceNode,
        dest: dest,
        sendLvl: 0.5, // Default start level (50%)
        isSend: true,
      );
      _handleRoutingResult(result);
    } else {
      // We still use removeRouting here because updateRoutingCall only UPSERTS
      final result = await removeRouting(
        widget.state,
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
    final result = await updateRoutingCall(
      widget.state,
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
    // 1. Gather Valid Main Outputs (Master + All Buses except self)
    final List<MapEntry<String, mixer_api.UiRoutingNode>> availableMainOutputs =
        [const MapEntry("Master", mixer_api.UiRoutingNode.master())];
    for (final bus in widget.mixerState.buses.values) {
      final node = mixer_api.UiRoutingNode.bus(bus.id);
      if (!_isSameNode(widget.sourceNode, node)) {
        availableMainOutputs.add(MapEntry(bus.name, node));
      }
    }

    // 2. Gather Valid Sends (All Buses except self AND except current Main Output)
    final List<MapEntry<String, mixer_api.UiRoutingNode>> availableSends = [];
    for (final bus in widget.mixerState.buses.values) {
      final node = mixer_api.UiRoutingNode.bus(bus.id);
      if (!_isSameNode(widget.sourceNode, node) &&
          (mainRoute == null || !_isSameNode(mainRoute!.destination, node))) {
        availableSends.add(MapEntry(bus.name, node));
      }
    }

    return AlertDialog(
      title: Text("Routing: ${widget.sourceName}"),
      backgroundColor: Colors.grey.shade900,
      titleTextStyle: const TextStyle(
        color: Colors.white,
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
            const Text(
              "MAIN OUTPUT (Pre-Fader)",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: mainRoute != null
                      ? _getNodeKeyStr(mainRoute!.destination)
                      : null,
                  isExpanded: true,
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.cyanAccent),
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
            const Text(
              "SENDS (Post-Fader)",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (availableSends.isEmpty)
              const Text(
                "No available buses to send to.",
                style: TextStyle(
                  color: Colors.white24,
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
                      activeThumbColor: Colors.cyanAccent,
                      onChanged: (v) => _toggleSend(entry.value, v),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: isEnabled ? Colors.white : Colors.white38,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: const SliderThemeData(
                          activeTrackColor: Colors.cyanAccent,
                          inactiveTrackColor: Colors.white10,
                          thumbColor: Colors.cyanAccent,
                          trackHeight: 2,
                          thumbShape: RoundSliderThumbShape(
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
                          color: isEnabled ? Colors.white54 : Colors.white24,
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
          child: const Text("Close", style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
