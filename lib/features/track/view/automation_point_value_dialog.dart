import 'package:flutter/material.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// Asks for an exact value for an automation point of [lane], typed in the
/// unit of the parameter the lane automates. Resolves with the new normalized
/// value (0..1), or null when cancelled or unchanged.
Future<double?> showAutomationPointValueDialog({
  required BuildContext context,
  required AutomationLaneDto lane,
  required AutomationPointDto point,
  required CurveSampler sampler,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) =>
        _AutomationPointValueDialog(lane: lane, point: point, sampler: sampler),
  );
}

class _AutomationPointValueDialog extends StatefulWidget {
  const _AutomationPointValueDialog({
    required this.lane,
    required this.point,
    required this.sampler,
  });

  final AutomationLaneDto lane;
  final AutomationPointDto point;

  /// Formats and parses values through the automated parameter.
  final CurveSampler sampler;

  @override
  State<_AutomationPointValueDialog> createState() =>
      _AutomationPointValueDialogState();
}

class _AutomationPointValueDialogState
    extends State<_AutomationPointValueDialog> {
  late final String _initialText = widget.sampler.valueText(
    widget.lane.id,
    widget.point.value,
  );
  late final TextEditingController _controller = TextEditingController(
    text: _initialText,
  );

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _initialText.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The typed text as a normalized lane value, or null when the parameter
  /// does not accept it.
  double? get _parsed =>
      widget.sampler.parseValue(widget.lane.id, _controller.text);

  void _submit() {
    final value = _parsed;
    if (value == null) return;
    // Confirming the prefilled text keeps the stored value untouched.
    Navigator.of(
      context,
    ).pop(_controller.text.trim() == _initialText ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final lane = widget.lane;
    final sampler = widget.sampler;
    final value = _parsed;

    return AlertDialog(
      title: Text('Set value: ${lane.label}'),
      content: SizedBox(
        width: 260,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText:
                'Value (${sampler.valueText(lane.id, 0)} to '
                '${sampler.valueText(lane.id, 1)})',
            border: const OutlineInputBorder(),
            // Out-of-range values are clamped by the parameter.
            helperText: value == null
                ? null
                : 'Sets ${sampler.valueText(lane.id, value)}',
            errorText: value == null ? 'Not a value of ${lane.label}' : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: value == null ? null : _submit,
          child: const Text('Set'),
        ),
      ],
    );
  }
}
