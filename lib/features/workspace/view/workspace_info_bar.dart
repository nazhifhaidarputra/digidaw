import 'package:flutter/material.dart';
import 'package:karbeat/core/widgets/background_jobs_indicator.dart';
import 'package:karbeat/features/track/view/performance_monitor.dart';

/// Height of the information bar along the top of the workspace.
const double kWorkspaceInfoBarHeight = 30;

/// A thin bar along the top of the workspace that only shows information:
/// the engine performance monitor and running background jobs. Controls live
/// in the dock at the bottom.
///
/// Shown on large screens only; on phones the space goes to the editor.
class WorkspaceInfoBar extends StatelessWidget {
  const WorkspaceInfoBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: kWorkspaceInfoBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: const Row(
        children: [
          Spacer(),
          BackgroundJobsIndicator(),
          SizedBox(width: 8),
          // The fixed height decides how many label rows fit per column.
          DawPerformanceMonitor(),
        ],
      ),
    );
  }
}
