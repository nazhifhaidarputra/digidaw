import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/services/project_file_actions.dart';
import 'package:karbeat/features/workspace/services/recent_projects_service.dart';
import 'package:karbeat/shared/models/menu_group.dart';
import 'package:karbeat/src/rust/api/settings.dart';

/// The items of the Open recent submenu, laid out like VS Code's: the recent
/// projects by path, most recent first, then Clear Recently Opened.
///
/// The list is read when the submenu opens, so it includes projects opened
/// since the menu was last shown. Every item acts through [run]: a menu item
/// runs its action after the menu has closed and this widget is gone.
class RecentProjectsMenuItems extends ConsumerWidget {
  const RecentProjectsMenuItems({super.key, required this.run});

  /// Closes the menus and runs a callback.
  final void Function(DawToolbarMenuActionCallback callback) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(recentProjectsProvider);
    final listed = projects.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...switch (projects) {
          AsyncData(value: final projects) when projects.isNotEmpty => [
            for (final project in projects)
              MenuItemButton(
                key: ValueKey('recent-project-${project.path}'),
                onPressed: () => run(
                  (context, ref) => project.exists
                      ? openRecentProject(context, ref, project.path)
                      : _offerToForget(context, ref, project),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Text(
                    project.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
          AsyncError() => [
            MenuItemButton(child: Text(tr('workspace-recent-read-failed'))),
          ],
          AsyncData() => [
            MenuItemButton(child: Text(tr('workspace-recent-empty'))),
          ],
          _ => [MenuItemButton(child: Text(tr('common-loading')))],
        },
        const Divider(height: 9),
        MenuItemButton(
          key: const ValueKey('recent-projects-clear'),
          onPressed: listed == null || listed.isEmpty
              ? null
              : () => run((context, ref) => _forgetAll(ref)),
          child: Text(tr('workspace-recent-clear')),
        ),
      ],
    );
  }
}

/// Empties the recent projects list.
Future<void> _forgetAll(WidgetRef ref) async {
  final cleared = await ref.read(recentProjectsServiceProvider).clear();
  if (cleared case Error(:final error)) {
    ref
        .read(notificationProvider.notifier)
        .error(error, title: tr('workspace-recent-clear-failed'));
  }
}

/// Tells the user [project] no longer exists and offers to remove it from the
/// list, as VS Code does for a recent entry that cannot be opened.
Future<void> _offerToForget(
  BuildContext context,
  WidgetRef ref,
  UiRecentProject project,
) async {
  final forget = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('workspace-recent-missing-title')),
      content: Text(
        tr('workspace-recent-missing-message', {'name': project.label}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('common-cancel')),
        ),
        FilledButton(
          key: const ValueKey('recent-project-forget'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr('common-remove')),
        ),
      ],
    ),
  );
  if (!(forget ?? false)) return;
  final removed = await ref
      .read(recentProjectsServiceProvider)
      .remove(project.path);
  if (removed case Error(:final error)) {
    ref
        .read(notificationProvider.notifier)
        .error(error, title: tr('workspace-recent-remove-failed'));
  }
}
