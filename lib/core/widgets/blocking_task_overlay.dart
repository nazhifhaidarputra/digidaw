import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';

/// Covers [child] with a modal spinner while [blockingTaskProvider] has an
/// active task, absorbing pointer, keyboard, and back-navigation input.
///
/// Focus is parked on the barrier while blocking, so app and screen shortcuts
/// cannot fire, and restored to the previously focused node afterwards.
class BlockingTaskOverlay extends ConsumerStatefulWidget {
  const BlockingTaskOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BlockingTaskOverlay> createState() =>
      _BlockingTaskOverlayState();
}

class _BlockingTaskOverlayState extends ConsumerState<BlockingTaskOverlay>
    with WidgetsBindingObserver {
  final FocusNode _barrierFocus = FocusNode(
    debugLabel: 'BlockingTaskOverlay',
    skipTraversal: true,
  );
  FocusNode? _restoreFocus;
  late final ProviderSubscription<bool> _blockingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _blockingSubscription = ref.listenManual(
      blockingTaskProvider.select((state) => state.isBlocking),
      (_, isBlocking) => _onBlockingChanged(isBlocking),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _blockingSubscription.close();
    WidgetsBinding.instance.removeObserver(this);
    _barrierFocus.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async => ref.read(blockingTaskProvider).isBlocking;

  void _onBlockingChanged(bool isBlocking) {
    if (isBlocking) {
      final current = FocusManager.instance.primaryFocus;
      if (current != _barrierFocus) _restoreFocus = current;
      // The barrier's Focus widget is inserted by the next build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(blockingTaskProvider).isBlocking) {
          _barrierFocus.requestFocus();
        }
      });
      return;
    }

    final restore = _restoreFocus;
    _restoreFocus = null;
    if (restore != null && restore.context != null && restore.canRequestFocus) {
      restore.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blockingTaskProvider);
    final active = state.active;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (active != null)
          Focus(
            focusNode: _barrierFocus,
            onKeyEvent: (_, _) => KeyEventResult.handled,
            child: _BlockingBarrier(
              label: active.label,
              pendingCount: state.pendingCount,
            ),
          ),
      ],
    );
  }
}

class _BlockingBarrier extends StatelessWidget {
  const _BlockingBarrier({required this.label, required this.pendingCount});

  final String label;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          dismissible: false,
          color: colors.scrim.withValues(alpha: 0.45),
        ),
        Center(
          child: Semantics(
            liveRegion: true,
            label: label,
            child: Material(
              key: const ValueKey('blocking-task-overlay'),
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      label,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$pendingCount more queued',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
