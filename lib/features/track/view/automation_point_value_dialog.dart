import 'package:flutter/material.dart';
import 'package:karbeat/src/rust/api/automation.dart';

/// Formats a normalized value with enough precision to round-trip what the
/// user typed, without a trailing tail of zeros.
String formatNormalizedValue(double value) {
  final fixed = value.toStringAsFixed(6);
  final trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? '${trimmed}0' : trimmed;
}

/// Asks for an exact normalized value (0..1) for an automation point of
/// [lane]. Resolves with the new value, or null when cancelled or unchanged.
Future<double?> showAutomationPointValueDialog({
  required BuildContext context,
  required AutomationLaneDto lane,
  required AutomationPointDto point,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _AutomationPointValueDialog(lane: lane, point: point),
  );
}

class _AutomationPointValueDialog extends StatefulWidget {
  const _AutomationPointValueDialog({required this.lane, required this.point});

  final AutomationLaneDto lane;
  final AutomationPointDto point;

  @override
  State<_AutomationPointValueDialog> createState() =>
      _AutomationPointValueDialogState();
}

class _AutomationPointValueDialogState
    extends State<_AutomationPointValueDialog> {
  late final String _initialText = formatNormalizedValue(widget.point.value);
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

  /// The typed value when it is a number within 0..1, otherwise null.
  double? get _parsed {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0 || value > 1) return null;
    return value;
  }

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
    final value = _parsed;
    final preview = value == null
        ? null
        : (lane.min + value * (lane.max - lane.min)).toStringAsFixed(2);

    return AlertDialog(
      title: Text('Set value: ${lane.label}'),
      content: SizedBox(
        width: 260,
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Normalized value (0 – 1)',
            border: const OutlineInputBorder(),
            helperText: preview == null ? null : 'Parameter value $preview',
            errorText: value == null ? 'Enter a number from 0 to 1' : null,
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
