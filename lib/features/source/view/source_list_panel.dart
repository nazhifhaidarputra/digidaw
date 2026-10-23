import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/features/plugins/services/plugin_ui_launcher.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/source/view/audio_properties_screen.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart';

/// Compact source list shown beside the track list on smaller displays.
///
/// It mirrors the Source view's instruments, audio clips, and patterns while
/// keeping the arranger visible, so a pattern or sample can be opened or put
/// on the timeline without leaving the track list.
class SourceListPanel extends ConsumerWidget {
  const SourceListPanel({super.key, required this.scrollController});

  final ScrollController scrollController;

  Future<void> _openGenerator(
    BuildContext context,
    WidgetRef ref,
    int id,
    UiGeneratorInstance generator,
  ) async {
    final instance = switch (generator.instanceType) {
      UiGeneratorInstanceType_Plugin(:final field0) => field0,
      _ => null,
    };
    final registryId = instance?.registryId;
    if (registryId == null) return;

    await openPluginInterface(
      context: context,
      ref: ref,
      target: UiPluginTarget.generator(id),
      registryId: registryId,
      instanceId: id,
      pluginName: instance?.name ?? 'Sampler',
    );
  }

  void _openAudioSource(BuildContext context, int sourceId, String sourceName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AudioPropertiesScreen(sourceId: sourceId, sourceName: sourceName),
      ),
    );
  }

  void _openPattern(WidgetRef ref, int patternId) {
    ref.read(pianoRollProvider.notifier).openPattern(patternId);
    ref.read(workspaceStateProvider.notifier).openPattern(patternId);
  }

  void _placeSource(
    WidgetRef ref, {
    required int id,
    required UiSourceType type,
  }) {
    final firstTrackId = ref
        .read(projectProvider)
        .value
        ?.tracks
        .keys
        .firstOrNull;
    ref
        .read(clipPlacementProvider.notifier)
        .startPlacement(id, type: type, initialTrackId: firstTrackId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final generators = ref.watch(
      projectProvider.select((s) => s.value?.generators ?? const IMapConst({})),
    );
    final patterns = ref.watch(
      projectProvider.select((s) => s.value?.patterns ?? const IMapConst({})),
    );
    final audioSourcesAsync = ref.watch(audioSourcesProvider);

    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _sectionHeader(context, 'Instruments'),
            if (generators.isEmpty)
              _emptyHint(context, 'No instruments.')
            else
              ...generators.entries.map((entry) {
                final id = entry.key;
                final generator = entry.value;
                final name = switch (generator.instanceType) {
                  UiGeneratorInstanceType_Plugin(:final field0) => field0.name,
                  _ => 'Sampler',
                };
                return _SourcePanelTile(
                  icon: Icons.piano,
                  color: colors.tertiary,
                  title: name,
                  subtitle: 'ID: $id',
                  onTap: () => _openGenerator(context, ref, id, generator),
                );
              }),
            _divider(context),
            _sectionHeader(context, 'Audio Clips'),
            audioSourcesAsync.when(
              data: (audioSources) {
                if (audioSources.isEmpty) {
                  return _emptyHint(context, 'No audio files.');
                }
                return Column(
                  children: [
                    for (final entry in audioSources.entries)
                      _SourcePanelTile(
                        icon: Icons.audio_file,
                        color: colors.primary,
                        title: entry.value.name,
                        subtitle:
                            'ID: ${entry.key} | ${entry.value.sampleRate} Hz',
                        onTap: () => _openAudioSource(
                          context,
                          entry.key,
                          entry.value.name,
                        ),
                        onPlace: () => _placeSource(
                          ref,
                          id: entry.key,
                          type: UiSourceType.audio,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading audio sources: $error',
                  style: TextStyle(color: colors.error, fontSize: 12),
                ),
              ),
            ),
            _divider(context),
            _sectionHeader(context, 'Patterns'),
            if (patterns.isEmpty)
              _emptyHint(context, 'No patterns.')
            else
              ...patterns.entries.map((entry) {
                final id = entry.key;
                final pattern = entry.value;
                return _SourcePanelTile(
                  icon: Icons.music_note,
                  color: colors.secondary,
                  title: pattern.name,
                  subtitle: 'ID: $id',
                  onTap: () => _openPattern(ref, id),
                  onPlace: () =>
                      _placeSource(ref, id: id, type: UiSourceType.midi),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        title,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyHint(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant);
}

class _SourcePanelTile extends StatelessWidget {
  const _SourcePanelTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onPlace,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPlace;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(left: 12, right: 4),
      leading: Icon(icon, color: color, size: 18),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurface, fontSize: 12),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
      ),
      trailing: onPlace == null
          ? null
          : IconButton(
              tooltip: 'Put in timeline',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: onPlace,
              icon: Icon(Icons.input, size: 16, color: colors.onSurfaceVariant),
            ),
      onTap: onTap,
    );
  }
}
