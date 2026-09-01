part of 'track_list_screen.dart';

sealed class _BrowserTreeRow {
  const _BrowserTreeRow(this.depth);

  final int depth;
}

class _BrowserDirectoryRow extends _BrowserTreeRow {
  const _BrowserDirectoryRow(this.directory, super.depth);

  final FileTree directory;
}

class _BrowserSampleRow extends _BrowserTreeRow {
  const _BrowserSampleRow(this.sample, super.depth);

  final BrowserSample sample;
}

class SampleBrowserPanel extends ConsumerWidget {
  const SampleBrowserPanel({super.key, required this.scrollController});

  final ScrollController scrollController;

  Future<void> _previewSample(
    BuildContext context,
    WidgetRef ref,
    BrowserSample sample,
  ) async {
    ref.read(workspaceStateProvider.notifier).selectBrowserSample(sample.path);
    final result = await AsyncValue.guard(
      () => audio_api.playFilePreview(
        ctx: ref.read(projectProvider.notifier).dawContext,
        filePath: sample.path,
      ),
    );
    if (result.hasError) {
      if (!context.mounted) return;
      ref
          .read(notificationProvider.notifier)
          .error(result.error!, title: 'Unable to preview sample');
      AppLogger.error(
        'Failed to preview browser sample: ${result.error}',
        stackTrace: result.stackTrace,
      );
    }
  }

  Future<void> _close(WidgetRef ref) async {
    final dawContext = ref.read(projectProvider).hasValue
        ? ref.read(projectProvider.notifier).dawContext
        : null;
    ref.read(workspaceStateProvider.notifier).closeBrowserPanel();
    if (dawContext == null) return;
    try {
      await audio_api.stopAllPreviews(ctx: dawContext);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to stop browser sample previews',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  List<_BrowserTreeRow> _visibleRows(BrowserPanelState state) {
    final rows = <_BrowserTreeRow>[];

    void append(FileTree tree, int depth) {
      rows.add(_BrowserDirectoryRow(tree, depth));
      if (!state.expandedDirectoryPaths.contains(tree.path)) return;
      for (final directory in tree.directories) {
        append(directory, depth + 1);
      }
      for (final sample in tree.samples) {
        rows.add(_BrowserSampleRow(sample, depth + 1));
      }
    }

    for (final tree in state.directories.values) {
      append(tree, 0);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(
      workspaceStateProvider.select((workspace) => workspace.browserPanelState),
    );
    final rows = _visibleRows(state);

    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.only(left: 10, right: 2),
            color: colors.surfaceContainer,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sample Browser',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurface, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Add sample directory',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: state.isLoadingDirectory
                      ? null
                      : () => ref
                            .read(workspaceStateProvider.notifier)
                            .addSampleDirectory(),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                ),
                IconButton(
                  tooltip: 'Close sample browser',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => unawaited(_close(ref)),
                  icon: const Icon(Icons.close, size: 17),
                ),
              ],
            ),
          ),
          if (state.isLoadingDirectory)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.audio_file_outlined,
                            color: colors.outline,
                            size: 32,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Add a directory to browse audio samples.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: state.isLoadingDirectory
                                ? null
                                : () => ref
                                      .read(workspaceStateProvider.notifier)
                                      .addSampleDirectory(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add directory'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: rows.length,
                      itemExtent: 28,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return switch (row) {
                          _BrowserDirectoryRow() => _directoryTile(
                            context,
                            ref,
                            row,
                            state,
                          ),
                          _BrowserSampleRow() => _sampleTile(
                            context,
                            ref,
                            row,
                            state,
                          ),
                        };
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _directoryTile(
    BuildContext context,
    WidgetRef ref,
    _BrowserDirectoryRow row,
    BrowserPanelState state,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isExpanded = state.expandedDirectoryPaths.contains(
      row.directory.path,
    );
    return InkWell(
      onTap: () => ref
          .read(workspaceStateProvider.notifier)
          .toggleBrowserDirectory(row.directory.path),
      child: Padding(
        padding: EdgeInsets.only(left: 4 + row.depth * 14.0, right: 6),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
            Icon(
              isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 16,
              color: colors.tertiary,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                row.directory.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurface, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sampleTile(
    BuildContext context,
    WidgetRef ref,
    _BrowserSampleRow row,
    BrowserPanelState state,
  ) {
    final colors = Theme.of(context).colorScheme;
    final selected = state.selectedSamplePath == row.sample.path;
    final tile = Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_previewSample(context, ref, row.sample)),
        child: Padding(
          padding: EdgeInsets.only(left: 8 + row.depth * 14.0, right: 8),
          child: Row(
            children: [
              Icon(
                selected ? Icons.volume_up : Icons.audio_file_outlined,
                size: 15,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  row.sample.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<BrowserSample>(
      data: row.sample,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => ref
          .read(workspaceStateProvider.notifier)
          .selectBrowserSample(row.sample.path),
      feedback: Material(
        elevation: 6,
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          width: 220,
          height: 28,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(Icons.audio_file, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  row.sample.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurface, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}
