import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/plugins/services/sidechain_support.dart';
import 'package:karbeat/features/plugins/widgets/sidechain_source_panel.dart';
import 'package:karbeat/src/rust/api/plugin.dart';

/// Opens the sidechain routing editor for an effect in a mixer rack.
Future<void> showSidechainInputDialog({
  required BuildContext context,
  required UiPluginTarget target,
  required int registryId,
  required String pluginName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SidechainInputDialog(
      target: target,
      registryId: registryId,
      pluginName: pluginName,
    ),
  );
}

class _SidechainInputDialog extends ConsumerStatefulWidget {
  const _SidechainInputDialog({
    required this.target,
    required this.registryId,
    required this.pluginName,
  });

  final UiPluginTarget target;
  final int registryId;
  final String pluginName;

  @override
  ConsumerState<_SidechainInputDialog> createState() =>
      _SidechainInputDialogState();
}

class _SidechainInputDialogState extends ConsumerState<_SidechainInputDialog> {
  late final Future<Result<bool>> _support = sidechainInputSupport(
    ref,
    widget.target,
    widget.registryId,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Sidechain: ${widget.pluginName}'),
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<Result<bool>>(
          future: _support,
          builder: (context, snapshot) {
            final panel = SidechainSourcePanel(target: widget.target);
            return switch (snapshot.data) {
              null => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              Ok(value: true) => SingleChildScrollView(child: panel),
              Ok() => Text(
                'This plugin has no sidechain input. Add a sidechain-capable '
                'plugin, such as a sidechain compressor, and key that one.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              // Routing still works when the plugin does have an aux input.
              Error(:final error) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SupportWarning(error: error),
                    const SizedBox(height: 12),
                    panel,
                  ],
                ),
              ),
            };
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Reports a failed capability query once and shows it inline.
class _SupportWarning extends ConsumerStatefulWidget {
  const _SupportWarning({required this.error});

  final Exception error;

  @override
  ConsumerState<_SupportWarning> createState() => _SupportWarningState();
}

class _SupportWarningState extends ConsumerState<_SupportWarning> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(notificationProvider.notifier)
          .error(widget.error, title: 'Could not read plugin inputs'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Could not confirm this plugin has a sidechain input. Routing a source '
      'here only has an effect if it does.',
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
