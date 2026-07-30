import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
// Make sure to import your ParameterInteractionWrapper here!
import 'package:karbeat/core/widgets/fine_grained_input.dart';
import 'package:karbeat/src/rust/api/automation.dart';

// ============================================================================
// FLOAT PARAMETER (Slider)
// ============================================================================
class DawFloatParam extends ConsumerWidget {
  final int paramId;
  final String name;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final double step;
  final String suffix;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final SliderInteraction sliderInteraction;
  final double? sliderWidth;
  final AutomationTargetDto? target;

  const DawFloatParam({
    super.key,
    required this.paramId,
    required this.name,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.step = 0.01,
    this.suffix = '',
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.sliderInteraction = SliderInteraction.slideThumb,
    this.sliderWidth,
    this.target,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayValue = value.toStringAsFixed(2);

    int? divisions;
    if (step > 0) {
      divisions = ((max - min) / step).round();
      if (divisions <= 0) divisions = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              '$displayValue$suffix',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        () {
          final sliderWithTheme = SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: Colors.grey.shade700,
              thumbColor: Colors.cyanAccent,
              overlayColor: Colors.cyanAccent.withAlpha(51),
              trackHeight: 4,
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: ParameterInteractionWrapper<double>(
              parameterName: name,
              value: value,
              defaultValue: defaultValue,
              min: min,
              max: max,
              step: step,
              onChanged: onChanged,
              onAddAutomation: () async {
                // TODO: Wire up automation lane creation using paramId
                AppLogger.debug("Create automation for $name ($paramId)");
                if (target == null) {
                  return;
                }
                ref
                    .read(automationProvider.notifier)
                    .handleAddAutomationForTarget(
                      target: target!,
                      label: name,
                      min: min,
                      max: max,
                      defaultValue: defaultValue,
                    );
              },
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeStart: onChangeStart,
                onChangeEnd: onChangeEnd,
                allowedInteraction: sliderInteraction,
              ),
            ),
          );
          if (sliderWidth != null) {
            return SizedBox(width: sliderWidth!, child: sliderWithTheme);
          }
          return sliderWithTheme;
        }(),
      ],
    );
  }
}

// ============================================================================
// CHOICE PARAMETER (Chips)
// ============================================================================
class DawChoiceParam extends StatelessWidget {
  final int paramId;
  final String name;
  final double value;
  final List<String> choices;
  final double defaultValue;
  final ValueChanged<double> onChanged;

  const DawChoiceParam({
    super.key,
    required this.paramId,
    required this.name,
    required this.value,
    required this.choices,
    required this.defaultValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentChoice = value.toInt().clamp(0, choices.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        ParameterInteractionWrapper<double>(
          parameterName: name,
          value: value,
          defaultValue: defaultValue,
          min: 0,
          max: (choices.length - 1).toDouble(),
          step: 1.0,
          onChanged: onChanged,
          onAddAutomation: () {
            // There are no automation for choice param (yet) 
            // debugPrint("Create automation for $name ($paramId)");
          },
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(choices.length, (index) {
              final isSelected = currentChoice == index;
              return GestureDetector(
                onTap: () => onChanged(index.toDouble()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.cyanAccent.withAlpha(51)
                        : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.cyanAccent
                          : Colors.grey.shade700,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    choices[index],
                    style: TextStyle(
                      color: isSelected ? Colors.cyanAccent : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// BOOL PARAMETER (Switch)
// ============================================================================
class DawBoolParam extends StatelessWidget {
  final int paramId;
  final String name;
  final double value;
  final double defaultValue;
  final ValueChanged<double> onChanged;

  const DawBoolParam({
    super.key,
    required this.paramId,
    required this.name,
    required this.value,
    required this.defaultValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = value >= 0.5;

    return ParameterInteractionWrapper<double>(
      parameterName: name,
      value: value,
      defaultValue: defaultValue,
      min: 0.0,
      max: 1.0,
      step: 1.0,
      onChanged: onChanged,
      onAddAutomation: () {
        // There are no automation for Bool param (yet) 
        // debugPrint("Create automation for $name ($paramId)");
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Switch(
            value: isOn,
            activeThumbColor: Colors.cyanAccent,
            onChanged: (val) => onChanged(val ? 1.0 : 0.0),
          ),
        ],
      ),
    );
  }
}
