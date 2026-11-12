import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/core/l10n/localizer.dart';
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
      tooltip: tr('common-jobs-tooltip'),
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
              single == null
                  ? tr('common-jobs-count', {'count': jobs.length})
                  : jobLabel(single.kind),
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
      UiJobState_Queued() => tr('common-jobs-queued'),
      _ => tr('common-jobs-running'),
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
  UiJobKind.projectExport => tr('common-job-export'),
  UiJobKind.bounce => tr('common-job-bounce'),
  UiJobKind.projectLoad => tr('common-job-project-load'),
  UiJobKind.projectSave => tr('common-job-project-save'),
  UiJobKind.channelTemplateSave => tr('common-job-template-save'),
  UiJobKind.channelTemplateLoad => tr('common-job-template-load'),
  UiJobKind.projectRestore => tr('common-job-project-restore'),
  UiJobKind.audioImport => tr('common-job-audio-import'),
  UiJobKind.waveformRender => tr('common-job-waveform-render'),
  UiJobKind.tempoDetection => tr('common-job-tempo-detection'),
  UiJobKind.pluginInstall => tr('common-job-plugin-install'),
  UiJobKind.pluginRemoval => tr('common-job-plugin-removal'),
  UiJobKind.pluginRetry => tr('common-job-plugin-retry'),
  UiJobKind.pluginReconfigure => tr('common-job-plugin-reconfigure'),
  UiJobKind.pluginScan => tr('common-job-plugin-scan'),
};
