import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;

typedef SidechainSourceLoader =
    Future<List<mixer_api.UiSidechainSource>> Function();
typedef SidechainSourceSetter =
    Future<void> Function(mixer_api.UiRoutingNode source, double? sendLevel);

/// Reusable editor for a plugin's auxiliary-input routing.
///
/// A null send level removes the route. A non-null value adds or updates it.
class SidechainSourcePanel extends ConsumerStatefulWidget {
  const SidechainSourcePanel({
    super.key,
    required this.target,
    this.loadSources,
    this.setSource,
  });

  final plugin_api.UiPluginTarget target;
  final SidechainSourceLoader? loadSources;
  final SidechainSourceSetter? setSource;

  @override
  ConsumerState<SidechainSourcePanel> createState() =>
      _SidechainSourcePanelState();
}

class _SidechainSourcePanelState extends ConsumerState<SidechainSourcePanel> {
  List<mixer_api.UiSidechainSource> _sources = const [];
  final Set<String> _busySources = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SidechainSourcePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _load();
    }
  }

  Future<List<mixer_api.UiSidechainSource>> _loadFromBackend() {
    final ctx = ref.read(projectProvider.notifier).dawContext;
    return mixer_api.getSidechainSources(
      ctx: ctx,
      sidechainPlugin: widget.target,
    );
  }

  Future<void> _setOnBackend(
    mixer_api.UiRoutingNode source,
    double? sendLevel,
  ) {
    final ctx = ref.read(projectProvider.notifier).dawContext;
    return mixer_api.setSidechainSource(
      ctx: ctx,
      plugin: widget.target,
      from: source,
      sendLevel: sendLevel,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sources = await (widget.loadSources ?? _loadFromBackend)();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _loading = false;
      });
    } catch (error) {
      ref.read(notificationProvider.notifier).error(error);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load sidechain sources: $error';
      });
    }
  }

  String _sourceKey(mixer_api.UiRoutingNode source) => switch (source) {
    mixer_api.UiRoutingNode_Track(:final field0) => 'track:$field0',
    mixer_api.UiRoutingNode_Bus(:final field0) => 'bus:$field0',
    mixer_api.UiRoutingNode_Master() => 'master',
    mixer_api.UiRoutingNode_PluginSidechain() => 'sidechain',
  };

  String _sourceType(mixer_api.UiRoutingNode source) => switch (source) {
    mixer_api.UiRoutingNode_Track() => 'Track',
    mixer_api.UiRoutingNode_Bus() => 'Bus',
    mixer_api.UiRoutingNode_Master() => 'Master',
    mixer_api.UiRoutingNode_PluginSidechain() => 'Sidechain',
  };

  void _replaceSource(int index, mixer_api.UiSidechainSource source) {
    final updated = List<mixer_api.UiSidechainSource>.of(_sources);
    updated[index] = source;
    _sources = updated;
  }

  Future<void> _toggleSource(int index, bool enabled) async {
    final previous = _sources[index];
    final key = _sourceKey(previous.source);
    if (_busySources.contains(key)) return;

    setState(() {
      _error = null;
      _busySources.add(key);
      _replaceSource(index, previous.copyWith(enabled: enabled));
    });

    try {
      final setter = widget.setSource ?? _setOnBackend;
      await setter(previous.source, enabled ? previous.sendLevel : null);
    } catch (error) {
      ref.read(notificationProvider.notifier).error(error);
      if (!mounted) return;
      setState(() {
        _replaceSource(index, previous);
        _error = 'Could not update ${previous.name}: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busySources.remove(key));
      }
    }
  }

  void _previewLevel(int index, double value) {
    setState(() {
      _replaceSource(index, _sources[index].copyWith(sendLevel: value));
    });
  }

  Future<void> _commitLevel(int index, double value) async {
    final source = _sources[index];
    if (!source.enabled) return;
    final key = _sourceKey(source.source);
    if (_busySources.contains(key)) return;

    setState(() {
      _error = null;
      _busySources.add(key);
    });
    try {
      final setter = widget.setSource ?? _setOnBackend;
      await setter(source.source, value);
    } catch (error) {
      ref.read(notificationProvider.notifier).error(error);
      if (!mounted) return;
      setState(() => _error = 'Could not update ${source.name}: $error');
      await _load();
    } finally {
      if (mounted) {
        setState(() => _busySources.remove(key));
      }
    }
  }

  String _formatLevel(double linear) {
    if (linear <= 0.0001) return '-∞ dB';
    final db = 20.0 * math.log(linear) / math.ln10;
    return '${db.toStringAsFixed(1)} dB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, color: colors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SIDECHAIN SOURCES',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh sources',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.error, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_sources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No valid track or bus sources are available.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          else
            ...List.generate(_sources.length, (index) {
              final source = _sources[index];
              final busy = _busySources.contains(_sourceKey(source.source));
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _sources.length - 1 ? 0 : 10,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  source.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.onSurface),
                                ),
                                Text(
                                  _sourceType(source.source),
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (busy)
                            const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          Switch(
                            value: source.enabled,
                            activeThumbColor: colors.primary,
                            onChanged: busy
                                ? null
                                : (value) => _toggleSource(index, value),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: colors.primary,
                                thumbColor: colors.primary,
                                inactiveTrackColor:
                                    colors.surfaceContainerHighest,
                              ),
                              child: Slider(
                                value: source.sendLevel.clamp(0.0, 1.0),
                                min: 0,
                                max: 1,
                                onChanged: source.enabled && !busy
                                    ? (value) => _previewLevel(index, value)
                                    : null,
                                onChangeEnd: source.enabled && !busy
                                    ? (value) => _commitLevel(index, value)
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              _formatLevel(source.sendLevel),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
