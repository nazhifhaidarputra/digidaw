import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/plugins/plugin_registry.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/features/plugins/view/dynamic_plugin_screen.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/source/view/audio_properties_screen.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';

class SourceListScreen extends ConsumerWidget {
  const SourceListScreen({super.key});

  Future<void> _pickFile(WidgetRef ref) async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.audio);

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      final ctx = ref.read(projectProvider.notifier).dawContext;
      await addAudioSource(ctx: ctx, filePath: path);
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
        onPressed: () => _pickFile(ref),
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
                  Widget screen;

                  if (!context.mounted) return;

                  try {
                    final availableGenerators = await ref
                        .read(audioPluginProvider.notifier)
                        .getAvailableGenerators();
                    final registryId = availableGenerators
                        .firstWhere((p) => p.id == genInstance?.registryId)
                        .id;
                    // final builder = SynthRegistry.getSynthBuilder(registryId);
                    screen = PluginRegistryFlutter.getGeneratorScreen(
                      registryId: registryId,
                      instanceId: id,
                    );
                  } catch (_) {
                    screen = DynamicPluginScreen(
                      target: UiPluginTarget.generator(id),
                      pluginName: name,
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => screen));
                },
                onPlace: null,
                // onDelete: () => ref.read(karbeatStateProvider).removeGenerator(id), // TODO implement
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

  const _SourceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onPlace,
    this.onRename,
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
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: colors.onSurfaceVariant),
        onSelected: (value) {
          if (value == 'place') onPlace?.call();
          if (value == 'rename') onRename?.call();
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
