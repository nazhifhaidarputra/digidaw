part of 'track_list_screen.dart';

/// The track list's single right-side panel. Browser samples and the source
/// list share the same split area and switch through tabs at the top.
class RightSidePanel extends ConsumerStatefulWidget {
  const RightSidePanel({
    super.key,
    required this.browserScrollController,
    required this.sourceScrollController,
  });

  final ScrollController browserScrollController;
  final ScrollController sourceScrollController;

  @override
  ConsumerState<RightSidePanel> createState() => _RightSidePanelState();
}

class _RightSidePanelState extends ConsumerState<RightSidePanel> {
  DawContext? _dawContext;

  @override
  void initState() {
    super.initState();
    final project = ref.read(projectProvider);
    _dawContext = project.hasValue
        ? ref.read(projectProvider.notifier).dawContext
        : null;
  }

  @override
  void dispose() {
    final dawContext = _dawContext;
    if (dawContext != null) {
      unawaited(_stopSamplePreviews(dawContext));
    }
    super.dispose();
  }

  Future<void> _stopSamplePreviews([DawContext? dawContext]) async {
    final ctx = dawContext ?? _dawContext;
    if (ctx == null) return;
    try {
      await audio_api.stopAllPreviews(ctx: ctx);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to stop browser sample previews',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _selectTab(RightPanelTab tab) {
    final current = ref.read(workspaceStateProvider).rightPanelTab;
    if (tab != RightPanelTab.browser && current == RightPanelTab.browser) {
      unawaited(_stopSamplePreviews());
    }
    ref.read(workspaceStateProvider.notifier).selectRightPanelTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tab = ref.watch(
      workspaceStateProvider.select((state) => state.rightPanelTab),
    );
    final isLoadingDirectory = ref.watch(
      workspaceStateProvider.select(
        (state) => state.browserPanelState.isLoadingDirectory,
      ),
    );

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
                    'Right Side Panel',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurface, fontSize: 12),
                  ),
                ),
                if (tab == RightPanelTab.browser)
                  IconButton(
                    tooltip: 'Add sample directory',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: isLoadingDirectory
                        ? null
                        : () => ref
                              .read(workspaceStateProvider.notifier)
                              .addSampleDirectory(),
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 17,
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Import audio',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => unawaited(importAudioSource(context, ref)),
                    icon: const Icon(Icons.add, size: 17),
                  ),
                IconButton(
                  tooltip: 'Close right panel',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref
                      .read(workspaceStateProvider.notifier)
                      .closeRightPanel(),
                  icon: const Icon(Icons.close, size: 17),
                ),
              ],
            ),
          ),
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _RightPanelTabButton(
                    icon: Icons.library_music,
                    label: 'Browser',
                    selected: tab == RightPanelTab.browser,
                    onTap: () => _selectTab(RightPanelTab.browser),
                  ),
                ),
                Expanded(
                  child: _RightPanelTabButton(
                    icon: Icons.group_work,
                    label: 'Sources',
                    selected: tab == RightPanelTab.sources,
                    onTap: () => _selectTab(RightPanelTab.sources),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (tab) {
              RightPanelTab.browser => SampleBrowserPanel(
                scrollController: widget.browserScrollController,
                showHeader: false,
              ),
              RightPanelTab.sources => SourceListPanel(
                scrollController: widget.sourceScrollController,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _RightPanelTabButton extends StatelessWidget {
  const _RightPanelTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    return Material(
      color: selected ? colors.surfaceContainerLow : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
