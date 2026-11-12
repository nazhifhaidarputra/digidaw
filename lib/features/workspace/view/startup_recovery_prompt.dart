import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/crash_recovery_provider.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/workspace/services/project_file_actions.dart';
import 'package:karbeat/src/rust/api/mitigation.dart' as mitigation_api;

/// Shows the crash recovery dialog once after startup when the previous run
/// left an auto saved copy or crash reports behind.
class StartupRecoveryPrompt extends ConsumerStatefulWidget {
  const StartupRecoveryPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupRecoveryPrompt> createState() =>
      _StartupRecoveryPromptState();
}

class _StartupRecoveryPromptState extends ConsumerState<StartupRecoveryPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(crashRecoveryProvider).needsAttention) return;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const CrashRecoveryDialog(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class CrashRecoveryDialog extends ConsumerWidget {
  const CrashRecoveryDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crashRecoveryProvider);
    final notifier = ref.read(crashRecoveryProvider.notifier);
    final recovery = state.recovery;

    return AlertDialog(
      key: const ValueKey('crash-recovery-dialog'),
      title: Text(
        state.previousSessionUnclean
            ? tr('workspace-recovery-unclean-title')
            : state.previousSessionForced
            ? tr('workspace-recovery-forced-title')
            : tr('workspace-recovery-reports-title'),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recovery != null) ...[
                _RecoveryCard(recovery: recovery, busy: state.isBusy),
                const SizedBox(height: 16),
              ],
              if (state.crashReports.isNotEmpty) ...[
                Text(
                  tr('workspace-recovery-reports-help'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final report in state.crashReports)
                  _CrashReportTile(report: report),
              ] else if (recovery == null)
                Text(tr('workspace-recovery-nothing')),
            ],
          ),
        ),
      ),
      actions: [
        if (state.crashReports.isNotEmpty)
          TextButton(
            onPressed: state.isBusy
                ? null
                : () => unawaited(notifier.dismissReports()),
            child: Text(tr('workspace-recovery-delete-reports')),
          ),
        FilledButton(
          onPressed: state.isBusy
              ? null
              : () {
                  notifier.dismiss();
                  Navigator.of(context).pop();
                },
          child: Text(tr('common-close')),
        ),
      ],
    );
  }
}

class _RecoveryCard extends ConsumerWidget {
  const _RecoveryCard({required this.recovery, required this.busy});

  final mitigation_api.UiRecoveryInfo recovery;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(crashRecoveryProvider.notifier);
    final savedAt = _formatMillis(recovery.savedAtMillis);
    final name = recovery.originalPath == null
        ? recovery.projectName
        : projectDisplayName(recovery.originalPath);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('workspace-recovery-auto-saved'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${tr('workspace-recovery-saved-from', {'name': name, 'time': savedAt})}'
              '${recovery.originalPath == null ? '' : '\n${recovery.originalPath}'}',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => unawaited(notifier.discardRecovery()),
                  child: Text(tr('workspace-recovery-discard')),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: busy ? null : () => unawaited(notifier.recover()),
                  child: Text(tr('workspace-recovery-recover')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CrashReportTile extends ConsumerWidget {
  const _CrashReportTile({required this.report});

  final mitigation_api.UiCrashReportSummary report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Text(
        '${report.code}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      title: Text(report.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_formatMillis(report.occurredAtMillis)} · v${report.appVersion}',
      ),
      trailing: IconButton(
        tooltip: tr('workspace-recovery-export-report'),
        icon: const Icon(Icons.download),
        onPressed: () async {
          final destination = await FilePicker.saveFile(
            dialogTitle: tr('workspace-recovery-export-dialog'),
            fileName: '${report.id}.json',
            type: FileType.custom,
            allowedExtensions: const ['json'],
          );
          if (destination == null) return;
          await ref
              .read(crashRecoveryProvider.notifier)
              .exportReport(report.id, destination);
        },
      ),
    );
  }
}

String _formatMillis(int millis) {
  final time = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
