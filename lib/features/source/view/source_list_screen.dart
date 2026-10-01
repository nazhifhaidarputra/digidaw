import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/features/plugins/services/plugin_ui_launcher.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/source/view/audio_properties_screen.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';

class SourceListScreen extends ConsumerWidget {
  const SourceListScreen({super.key});

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    final notifications = ref.read(notificationProvider.notifier);
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(type: FileType.audio);
    } catch (error, stackTrace) {
      AppLogger.error('Could not select an audio file: $error');
      notifications.error(
        error,
        title: 'Could not select audio',
        stackTrace: stackTrace,
      );
      return;
    }

    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;

    final projectNotifier = ref.read(projectProvider.notifier);
    final importResult = await ref
        .read(blockingTaskProvider.notifier)
        .run(
          label: 'Loading audio...',
          task: () => projectNotifier.loadAudioSource(path),
        );

    if (context.mounted && importResult.isOk()) {
      ref.invalidate(audioSourcesProvider);
    }
  }

  Future<void> _renamePattern(
    BuildContext context,
    WidgetRef ref,
    int patternId,
    String currentName,
  ) async {
    var pendingName = currentName;
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Rename Pattern"),
        content: TextFormField(
          initialValue: currentName,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "New pattern name",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => pendingName = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, pendingName),
            child: const Text("Rename"),
          ),
        ],
      ),
    );

    final trimmedName = newName?.trim();
    if (!context.mounted ||
        trimmedName == null ||
        trimmedName.isEmpty ||
        trimmedName == currentName) {
      return;
    }

    await ref
        .read(pianoRollProvider.notifier)
        .renamePattern(patternId: patternId, newName: trimmedName);
  }

  /// Number of timeline clips that play the audio source [sourceId].
  static int audioSourceClipCount(Iterable<UiTrack> tracks, int sourceId) =>
      tracks
          .expand((track) => track.clips)
          .where(
            (clip) => switch (clip.source) {
              UiClipSource_Audio(sourceId: final id) => id == sourceId,
              _ => false,
            },
          )
          .length;

  /// Asks before deleting an audio source, naming how many clips go with it.
  Future<void> _deleteAudioSource(
    BuildContext context,
    WidgetRef ref,
    int sourceId,
    String name,
  ) async {
    final tracks =
        ref.read(projectProvider).value?.tracks.values ?? const <UiTrack>[];
    final clipCount = audioSourceClipCount(tracks, sourceId);
    final clipText = switch (clipCount) {
      0 => 'No clip on the timeline uses it.',
      1 => '1 clip that plays it will be removed from the timeline.',
      _ => '$clipCount clips that play it will be removed from the timeline.',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete audio source?'),
        content: Text(
          '“$name” will be removed from the project. $clipText\n\n'
          'The audio file on disk is not deleted, and you can undo this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // A placement of this source would create a clip with nothing to play.
    final placement = ref.read(clipPlacementProvider);
    if (placement.sourceType == UiSourceType.audio &&
        placement.sourceId == sourceId) {
      ref.read(clipPlacementProvider.notifier).cancelPlacement();
    }
    await ref.read(projectProvider.notifier).removeAudioSource(sourceId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // Access the source map from state
    final audioSourcesAsync = ref.watch(audioSourcesProvider);

    final generators = ref.watch(
      projectProvider.select((s) => s.value?.generators ?? const IMapConst({})),
    );

    final patterns = ref.watch(
      projectProvider.select((s) => s.value?.patterns ?? const IMapConst({})),
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickFile(context, ref),
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          // ================================================
          // 1. GENERATORS SECTION
          // ================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Instruments / Generators",
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          if (generators.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "No Instruments.",
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final id = generators.keys.elementAt(index);
              final gen = generators.values.elementAt(index);
              final instanceType = gen.instanceType;
              final name = switch (instanceType) {
                UiGeneratorInstanceType_Plugin(:final field0) => field0.name,
                _ => "Sampler",
              };

              final genInstance = switch (instanceType) {
                UiGeneratorInstanceType_Plugin(:final field0) => field0,
                _ => null,
              };

              return _SourceTile(
                title: name,
                subtitle: "ID: $id",
                icon: Icons.piano,
                color: colors.tertiary,
                onTap: () async {
                  final registryId = genInstance?.registryId;
                  if (registryId == null) return;
                  await openPluginInterface(
                    context: context,
                    ref: ref,
                    target: UiPluginTarget.generator(id),
                    registryId: registryId,
                    instanceId: id,
                    pluginName: name,
                  );
                },
                onPlace: null,
              );
            }, childCount: generators.length),
          ),

          SliverToBoxAdapter(child: Divider(color: colors.outlineVariant)),

          // ================================================
          // 2. AUDIO CLIPS SECTION
          // ================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                "Audio Clips",
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          audioSourcesAsync.when(
            data: (audioSources) {
              if (audioSources.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "No Audio Files.",
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final id = audioSources.keys.elementAt(index);
                  final source = audioSources.values.elementAt(index);

                  return _SourceTile(
                    title: source.name,
                    subtitle: "ID: $id | ${source.sampleRate} Hz",
                    icon: Icons.audio_file,
                    color: colors.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AudioPropertiesScreen(
                            sourceId: id,
                            sourceName: source.name,
                          ),
                        ),
                      );
                    },
                    onPlace: () {
                      final firstTrackId = ref
                          .read(projectProvider)
                          .value
                          ?.tracks
                          .keys
                          .firstOrNull;
                      ref
                          .read(clipPlacementProvider.notifier)
                          .startPlacement(
                            id,
                            type: UiSourceType.audio,
                            initialTrackId: firstTrackId,
                          );
                    },
                    onDelete: () =>
                        _deleteAudioSource(context, ref, id, source.name),
                  );
                }, childCount: audioSources.length),
              );
            },

            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

            error: (err, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Error loading audio sources: $err",
                  style: TextStyle(color: colors.error),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: Divider(color: colors.outlineVariant)),

          // Patterns list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                "Patterns",
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          if (patterns.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "No Patterns.",
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final id = patterns.keys.elementAt(index);
              final pattern = patterns.values.elementAt(index);
              return _SourceTile(
                title: pattern.name,
                subtitle: "ID: $id | ${pattern.name}",
                icon: Icons.music_note,
                color: colors.secondary,
                onTap: () {
                  ref.read(pianoRollProvider.notifier).openPattern(id);
                },
                onPlace: () {
                  final firstTrackId = ref
                      .read(projectProvider)
                      .value
                      ?.tracks
                      .keys
                      .firstOrNull;
                  ref
                      .read(clipPlacementProvider.notifier)
                      .startPlacement(
                        id,
                        type: UiSourceType.midi,
                        initialTrackId: firstTrackId,
                      );
                },
                onRename: () => _renamePattern(context, ref, id, pattern.name),
              );
            }, childCount: patterns.length),
          ),

          // Extra padding at bottom for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onPlace;
  final VoidCallback? onRename;

  /// Deletes the item; the menu entry is hidden when it cannot be deleted.
  final VoidCallback? onDelete;

  const _SourceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onPlace,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: colors.onSurface)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
      // Items without any action get no menu button.
      trailing: onPlace == null && onRename == null && onDelete == null
          ? null
          : PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colors.onSurfaceVariant),
              onSelected: (value) {
                if (value == 'place') onPlace?.call();
                if (value == 'rename') onRename?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => [
                if (onPlace != null)
                  const PopupMenuItem(
                    value: 'place',
                    child: Row(
                      children: [
                        Icon(Icons.input),
                        SizedBox(width: 8),
                        Text("Put in timeline"),
                      ],
                    ),
                  ),
                if (onRename != null)
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text("Rename"),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete),
                        SizedBox(width: 8),
                        Text("Delete"),
                      ],
                    ),
                  ),
              ],
            ),
      onTap: onTap,
    );
  }
}
