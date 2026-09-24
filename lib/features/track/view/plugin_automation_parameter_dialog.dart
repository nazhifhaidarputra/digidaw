import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;

/// Opens the automatable parameter picker for a generator or effect plugin.
Future<void> showPluginAutomationParameterDialog({
  required BuildContext context,
  required plugin_api.UiPluginTarget target,
  required String ownerName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        PluginAutomationParameterDialog(target: target, ownerName: ownerName),
  );
}

/// Searchable picker for automatable parameters exposed by a plugin.
class PluginAutomationParameterDialog extends ConsumerStatefulWidget {
  /// Generator or effect instance used for parameter discovery.
  final plugin_api.UiPluginTarget target;

  /// Track or effect label displayed in the dialog title.
  final String ownerName;

  /// Creates a parameter picker for one plugin instance.
  const PluginAutomationParameterDialog({
    super.key,
    required this.target,
    required this.ownerName,
  });

  @override
  ConsumerState<PluginAutomationParameterDialog> createState() =>
      _PluginAutomationParameterDialogState();
}

class _PluginAutomationParameterDialogState
    extends ConsumerState<PluginAutomationParameterDialog> {
  String _query = '';
  int? _submittingParameterId;

  String _groupName(plugin_api.UiPluginParameter parameter) {
    final group = parameter.group.trim();
    return group.isEmpty ? 'Other' : group;
  }

  String _metadata(plugin_api.UiPluginParameter parameter) {
    final type = parameter.paramType.name;
    if (parameter.choices.isNotEmpty) {
      return '$type · ${parameter.choices.length} choices';
    }
    if (parameter.paramType == plugin_api.UiParameterType.bool) {
      return type;
    }
    return '$type · ${parameter.min} – ${parameter.max}';
  }

  bool _matches(PluginAutomationCandidate candidate) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final parameter = candidate.parameter;
    return parameter.name.toLowerCase().contains(query) ||
        parameter.group.toLowerCase().contains(query) ||
        parameter.path.toLowerCase().contains(query);
  }

  Future<void> _addAutomation(PluginAutomationCandidate candidate) async {
    if (_submittingParameterId != null || candidate.alreadyAutomated) return;
    setState(() => _submittingParameterId = candidate.parameter.id);

    final result = await ref
        .read(automationProvider.notifier)
        .handleAddPluginParameterAutomation(
          target: widget.target,
          parameter: candidate.parameter,
        );
    if (!mounted) return;

    if (result.hasValue) {
      Navigator.of(context).pop();
      return;
    }

    ref.invalidate(pluginAutomationCandidatesProvider(widget.target));
    setState(() => _submittingParameterId = null);
  }

  Widget _buildCandidates(List<PluginAutomationCandidate> candidates) {
    if (candidates.isEmpty) {
      return const Center(
        child: Text('This plugin has no automatable parameters.'),
      );
    }

    final filtered = candidates.where(_matches).toList(growable: false);
    if (filtered.isEmpty) {
      return const Center(child: Text('No parameters match this search.'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final candidate = filtered[index];
        final parameter = candidate.parameter;
        final group = _groupName(parameter);
        final showGroup =
            index == 0 || _groupName(filtered[index - 1].parameter) != group;
        final isSubmitting = _submittingParameterId == parameter.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showGroup)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  group,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ListTile(
              enabled:
                  !candidate.alreadyAutomated && _submittingParameterId == null,
              title: Text(parameter.name),
              subtitle: Text(
                parameter.path.isEmpty
                    ? _metadata(parameter)
                    : '${_metadata(parameter)} · ${parameter.path}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: candidate.alreadyAutomated
                  ? const Text('Already automated')
                  : isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onTap: () => _addAutomation(candidate),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(
      pluginAutomationCandidatesProvider(widget.target),
    );

    return AlertDialog(
      title: Text(
        'Add automation on ${widget.ownerName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 620,
        height: 540,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search parameters...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: candidates.when(
                data: _buildCandidates,
                loading: () => const Center(
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load plugin parameters.\n$error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => ref.invalidate(
                            pluginAutomationCandidatesProvider(widget.target),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
