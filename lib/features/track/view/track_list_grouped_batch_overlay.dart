part of 'track_list_screen.dart';

class _GroupedBatchOverlay extends ConsumerWidget {
  final List<int> trackIds;
  final double itemHeight;
  final ScrollController horizontalScrollController;
  final ScrollController timelineController;
  final ClipDragController clipDragController;

  const _GroupedBatchOverlay({
    required this.trackIds,
    required this.itemHeight,
    required this.horizontalScrollController,
    required this.timelineController,
    required this.clipDragController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedBuilder(
      animation: clipDragController,
      builder: (context, child) {
        if (!clipDragController.isActive) return const SizedBox();

        final trackListState = ref.read(trackListStateProvider);
        final selectedClipIds = trackListState.selectedClipIds;
        final selectedTrackId = trackListState.selectedTrackId;

        if (selectedTrackId == null || selectedClipIds.isEmpty) {
          return const SizedBox();
        }

        final projectState = ref.read(projectProvider).value;
        if (projectState == null) return const SizedBox();

        final track = projectState.tracks[selectedTrackId];
        if (track == null) return const SizedBox();

        final zoomLevel = ref.read(workspaceStateProvider).horizontalZoomLevel;
        double scrollX = horizontalScrollController.hasClients
            ? horizontalScrollController.offset
            : 0;
        double scrollY = timelineController.hasClients
            ? timelineController.offset
            : 0;

        final trackIndex = trackIds.indexWhere((t) => t == selectedTrackId);
        if (trackIndex < 0) return const SizedBox();

        // Pull the live math directly from the controller
        final snappedDelta = clipDragController.snappedDeltaSamples;
        final verticalDy = clipDragController.verticalDragDy;

        Widget groupedClips = Stack(
          clipBehavior: Clip.none,
          children: selectedClipIds.map((clipId) {
            final clip = track.clips.where((c) => c.id == clipId).firstOrNull;
            if (clip == null) return const SizedBox();

            final bpm = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
            final sr = projectState.hardwareConfig.sampleRate;
            final screenLeft =
                (clip.startTimeInTicks(bpm, sr) / zoomLevel) - scrollX;
            final screenTop = (trackIndex * itemHeight) - scrollY + 30 + 2;
            final clipWidth = clip.loopLengthInTicks(bpm, sr) / zoomLevel;

            double activeWidth = clipWidth;
            double activeLeft = screenLeft;

            if (clipDragController.action == BatchDragAction.resizeRight) {
              activeWidth += (snappedDelta / zoomLevel);
            } else if (clipDragController.action ==
                BatchDragAction.resizeLeft) {
              activeLeft += (snappedDelta / zoomLevel);
              activeWidth -= (snappedDelta / zoomLevel);
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

        if (clipDragController.action == BatchDragAction.move) {
          groupedClips = Transform.translate(
            offset: Offset((snappedDelta / zoomLevel), verticalDy),
            child: groupedClips,
          );
        }

        return Positioned.fill(child: IgnorePointer(child: groupedClips));
      },
    );
  }
}
