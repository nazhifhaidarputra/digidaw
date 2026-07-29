part of 'track_list_screen.dart';

class _GroupedBatchOverlay extends ConsumerWidget {
  final List<int> trackIds;
  final double itemHeight;
  final ScrollController horizontalScrollController;
  final ScrollController timelineController;

  const _GroupedBatchOverlay({
    required this.trackIds,
    required this.itemHeight,
    required this.horizontalScrollController,
    required this.timelineController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placementState = ref.watch(clipPlacementProvider);
    if (!placementState.isDraggingExisting) return const SizedBox();

    final selectedClipIds = placementState.draggedClipIds;
    final selectedTrackId = placementState.originalTrackId;
    final targetTrackId = placementState.trackId;

    if (selectedTrackId == -1 || selectedClipIds.isEmpty) {
      return const SizedBox();
    }

    final projectState = ref.read(projectProvider).value;
    if (projectState == null) return const SizedBox();

    final track = projectState.tracks[selectedTrackId];
    if (track == null) return const SizedBox();

    final zoomLevel = ref.watch(
      workspaceStateProvider.select((s) => s.horizontalZoomLevel),
    );
    double scrollX = horizontalScrollController.hasClients
        ? horizontalScrollController.offset
        : 0;
    double scrollY = timelineController.hasClients
        ? timelineController.offset
        : 0;

    final targetTrackIndex = trackIds.indexWhere((t) => t == targetTrackId);
    if (targetTrackIndex < 0) return const SizedBox();

    final snappedDelta = placementState.snappedDeltaTicks;

    Widget groupedClips = Stack(
      clipBehavior: Clip.none,
      children: selectedClipIds.map((clipId) {
        final clip = track.clips.where((c) => c.id == clipId).firstOrNull;
        if (clip == null) return const SizedBox();

        final bpm =
            ref.watch(transportProvider.select((s) => s.value?.state?.bpm)) ??
            120.0;
        final sr =
            ref.watch(transportProvider.select((s) => s.value?.sampleRate)) ??
            48000;
        final screenLeft =
            (clip.startTimeInTicks(bpm, sr) / zoomLevel) - scrollX;
        final screenTop = (targetTrackIndex * itemHeight) - scrollY + 30 + 2;
        final clipWidth = clip.loopLengthInTicks(bpm, sr) / zoomLevel;

        double activeWidth = clipWidth;
        double activeLeft = screenLeft;

        if (placementState.dragAction == BatchDragAction.resizeRight) {
          activeWidth += (snappedDelta / zoomLevel);
        } else if (placementState.dragAction == BatchDragAction.resizeLeft) {
          activeLeft += (snappedDelta / zoomLevel);
          activeWidth -= (snappedDelta / zoomLevel);
        } else if (placementState.dragAction == BatchDragAction.move) {
          activeLeft += (snappedDelta / zoomLevel);
        }

        return Positioned(
          left: activeLeft,
          top: screenTop,
          width: activeWidth < 1 ? 1 : activeWidth,
          height: itemHeight - 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withAlpha(150),
              border: Border.all(color: Colors.cyanAccent, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                clip.name,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }).toList(),
    );

    return Positioned.fill(child: IgnorePointer(child: groupedClips));
  }
}
