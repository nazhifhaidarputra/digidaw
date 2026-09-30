import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/src/rust/api/jobs.dart';

/// Compact spinner for running background jobs; tap it to list and cancel them.
///
/// Renders nothing while no job is running.
class BackgroundJobsIndicator extends ConsumerWidget {
  const BackgroundJobsIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(backgroundJobsProvider.select((s) => s.active));
    if (jobs.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final single = jobs.length == 1 ? jobs.values.first : null;
    final fraction = switch (single?.state) {
      UiJobState_Progress(:final fraction) => fraction,
      _ => null,
    };

    return PopupMenuButton<int>(
      tooltip: 'Background tasks',
      onSelected: (id) => ref.read(backgroundJobsProvider.notifier).cancel(id),
      itemBuilder: (context) => [
        for (final job in jobs.values)
          PopupMenuItem<int>(
            value: job.id,
            child: _JobRow(job: job),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              single == null ? '${jobs.length} tasks' : jobLabel(single.kind),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});

  final BackgroundJob job;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = switch (job.state) {
      UiJobState_Progress(:final fraction) => '${(fraction * 100).round()}%',
      UiJobState_Queued() => 'Queued',
      _ => 'Running',
    };
    return Row(
      children: [
        Expanded(child: Text(jobLabel(job.kind))),
        Text(progress, style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(width: 8),
        Icon(Icons.close, size: 16, color: colors.error),
      ],
    );
  }
}

/// Short user-facing name of a job kind.
String jobLabel(UiJobKind kind) => switch (kind) {
  UiJobKind.projectExport => 'Exporting',
  UiJobKind.projectLoad => 'Loading project',
  UiJobKind.projectSave => 'Saving project',
  UiJobKind.projectRestore => 'Restoring project',
  UiJobKind.audioImport => 'Importing audio',
  UiJobKind.waveformRender => 'Rendering audio',
  UiJobKind.tempoDetection => 'Detecting tempo',
  UiJobKind.pluginInstall => 'Loading plugin',
  UiJobKind.pluginRemoval => 'Removing plugin',
  UiJobKind.pluginRetry => 'Reloading plugin',
  UiJobKind.pluginReconfigure => 'Reconfiguring plugins',
  UiJobKind.pluginScan => 'Scanning plugins',
};
