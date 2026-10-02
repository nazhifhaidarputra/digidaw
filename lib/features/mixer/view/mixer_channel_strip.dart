import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/widgets/channel_toggle_button.dart';
import 'package:karbeat/core/widgets/db_level_meter.dart';
import 'package:karbeat/core/widgets/digidaw_plugin_widgets/widgets.dart';
import 'package:karbeat/core/widgets/fine_grained_input.dart';
import 'package:karbeat/core/widgets/rainbow_sparkle.dart';
import 'package:karbeat/features/mixer/services/mixer_channel_targets.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/project.dart' show DawContext;

/// One mixer channel: pan, fader, meter, mute and solo for a track, a bus,
/// or the master.
class MixerChannelStrip extends ConsumerStatefulWidget {
  final UiMixerChannelTarget target;
  final bool isSelected;
  final VoidCallback? onTap;

  /// Shown under the mute and solo buttons, such as the output indicator.
  final Widget? footer;

  const MixerChannelStrip({
    super.key,
    required this.target,
    this.isSelected = false,
    this.onTap,
    this.footer,
  });

  @override
  ConsumerState<MixerChannelStrip> createState() => _MixerChannelStripState();
}

class _MixerChannelStripState extends ConsumerState<MixerChannelStrip> {
  List<ParameterSpecDTO>? _specs;

  DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;

  @override
  void initState() {
    super.initState();
    _loadSpecs();
  }

  @override
  void didUpdateWidget(covariant MixerChannelStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) _loadSpecs();
  }

  Future<void> _loadSpecs() async {
    final target = widget.target;
    List<ParameterSpecDTO>? fetchedSpecs;
    try {
      fetchedSpecs = await switch (target) {
        UiMixerChannelTarget_Master() => getMasterChannelSpecs(ctx: _ctx),
        UiMixerChannelTarget_Bus(:final field0) => getBusMixerChannelSpecs(
          ctx: _ctx,
          busId: field0,
        ),
        UiMixerChannelTarget_Track(:final field0) => getTrackMixerChannelSpecs(
          ctx: _ctx,
          trackId: field0,
        ),
      };
    } catch (e) {
      AppLogger.error("Failed to load channel specs: $e");
      ref.read(notificationProvider.notifier).error(e);
    }

    if (mounted && target == widget.target) {
      setState(() {
        _specs = fetchedSpecs;
      });
    }
  }

  // Fallback specs keep the controls laid out until the real ones arrive.
  ParameterSpecDTO _specOf(int id, ParameterSpecDTO fallback) =>
      _specs?.where((spec) => spec.id == id).firstOrNull ?? fallback;

  static const _defaultVolumeSpec = ParameterSpecDTO(
    id: 1,
    name: 'Volume',
    group: 'MixerChannel',
    value: 0.0,
    min: -100.0,
    max: 6.0,
    defaultValue: 0.0,
    step: 0.1,
    valueType: ParameterValueTypeDTO.float,
    choices: [],
  );

  static const _defaultPanSpec = ParameterSpecDTO(
    id: 2,
    name: 'Pan',
    group: 'MixerChannel',
    value: 0.0,
    min: -1.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 0.01,
    valueType: ParameterValueTypeDTO.float,
    choices: [],
  );

  AutomationTargetDto _automationTarget({required bool isPan}) {
    final mixTarget = isPan
        ? const MixerChannelParamTargetDto.pan()
        : const MixerChannelParamTargetDto.volume();

    return switch (widget.target) {
      UiMixerChannelTarget_Master() => AutomationTargetDto.master(
        MasterAutomationTargetDto.mixerChannel(mixTarget),
      ),
      UiMixerChannelTarget_Bus(:final field0) => AutomationTargetDto.bus(
        busId: field0,
        mixTarget: mixTarget,
      ),
      UiMixerChannelTarget_Track(:final field0) => AutomationTargetDto.track(
        trackId: field0,
        trackTarget: TrackAutomationTargetDto.mixerChannel(mixTarget),
      ),
    };
  }

  void _setParam(UiMixerChannelParams param) {
    ref
        .read(mixerStateProvider.notifier)
        .setChannelParam(target: widget.target, param: param);
  }

  void _setTouched(String paramName, bool touched) {
    final mixer = ref.read(mixerStateProvider.notifier);
    final key = mixer.touchKeyOf(widget.target);
    if (touched) {
      mixer.markParamTouched(key, paramName);
    } else {
      mixer.markParamReleased(key, paramName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final target = widget.target;
    final isMaster = target is UiMixerChannelTarget_Master;
    final identity = ref.watch(
      projectProvider.select((s) {
        final store = s.value;
        if (store == null) return null;
        return (
          channel: target.channelIn(store.mixer),
          name: target.displayName(store.mixer, store.tracks),
          color: target.colorIn(store.mixer, store.tracks),
        );
      }),
    );
    final channel = identity?.channel;
    if (identity == null || channel == null) return const SizedBox(width: 92);

    final magnitude = ref.watch(
      mixerStateProvider.select(
        (state) => switch (target) {
          UiMixerChannelTarget_Track(:final field0) =>
            state.trackMagnitudes[field0] ?? 0.0,
          UiMixerChannelTarget_Bus(:final field0) =>
            state.busMagnitudes[field0] ?? 0.0,
          UiMixerChannelTarget_Master() => state.masterMagnitude,
        },
      ),
    );
    final name = identity.name;
    final accentColor = isMaster
        ? colors.tertiary
        : identity.color ?? colors.primary;
    const labelRadius = BorderRadius.vertical(top: Radius.circular(9));
    final label = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isMaster
          ? null
          : BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: labelRadius,
            ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMaster ? Colors.black87 : accentColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );

    final strip = Container(
      width: 84,
      decoration: BoxDecoration(
        color: isMaster
            ? colors.tertiaryContainer.withValues(alpha: 0.4)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        // The master outline is the animated rainbow drawn around the strip.
        border: isMaster
            ? null
            : Border.all(
                color: widget.isSelected ? accentColor : colors.outlineVariant,
                width: widget.isSelected ? 2 : 1,
              ),
        boxShadow: widget.isSelected
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // === Channel Label ===
          if (isMaster)
            RainbowSparkle(borderRadius: labelRadius, child: label)
          else
            label,

          const SizedBox(height: 6),

          // === Pan Knob ===
          _PanKnob(
            value: channel.pan,
            spec: _specOf(2, _defaultPanSpec),
            accentColor: accentColor,
            automationTarget: _automationTarget(isPan: true),
            onChanged: (value) => _setParam(UiMixerChannelParams.pan(value)),
            onChangeStart: () => _setTouched('pan', true),
            onChangeEnd: () => _setTouched('pan', false),
          ),

          const SizedBox(height: 12),

          // === Volume Fader ===
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Semantics(
                    label: '$name output level',
                    value: '${magnitudeToDb(magnitude).toStringAsFixed(1)} dB',
                    child: DbLevelMeter(magnitude: magnitude, showScale: true),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _VolumeFader(
                    value: channel.volume,
                    spec: _specOf(1, _defaultVolumeSpec),
                    accentColor: accentColor,
                    onChanged: (value) =>
                        _setParam(UiMixerChannelParams.volume(value)),
                    onChangeStart: () => _setTouched('volume', true),
                    onChangeEnd: () => _setTouched('volume', false),
                    automationTarget: _automationTarget(isPan: false),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // === dB readout ===
          Text(
            formatChannelVolume(channel.volume),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 9),
          ),

          const SizedBox(height: 6),

          // === Mute / Solo ===
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChannelToggleButton(
                label: 'M',
                isActive: channel.mute,
                activeColor: colors.error,
                onTap: () =>
                    _setParam(UiMixerChannelParams.mute(!channel.mute)),
              ),
              const SizedBox(width: 4),
              ChannelToggleButton(
                label: 'S',
                isActive: channel.solo,
                activeColor: colors.tertiary,
                onTap: () =>
                    _setParam(UiMixerChannelParams.solo(!channel.solo)),
              ),
            ],
          ),

          if (widget.footer case final footer?) ...[
            const SizedBox(height: 6),
            footer,
          ],

          const SizedBox(height: 8),
        ],
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: isMaster
            ? RainbowSparkle(
                borderRadius: BorderRadius.circular(10),
                borderWidth: widget.isSelected ? 2.5 : 1.5,
                child: strip,
              )
            : strip,
      ),
    );
  }
}

/// Fader volume in dB, with the bottom of the range shown as silence.
String formatChannelVolume(double volumeDb) {
  if (volumeDb <= -60.0) return '-∞ dB';
  return '${volumeDb.toStringAsFixed(1)} dB';
}

/// Pan position as "C", "L50" or "R50".
String formatChannelPan(double pan) {
  if (pan == 0) return 'C';
  return pan < 0 ? 'L${(-pan * 100).round()}' : 'R${(pan * 100).round()}';
}

// =========================================================
// Pan Knob
// =========================================================

class _PanKnob extends ConsumerWidget {
  final double value;
  final ParameterSpecDTO spec;
  final Color accentColor;
  final AutomationTargetDto automationTarget;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  const _PanKnob({
    required this.value,
    required this.spec,
    required this.accentColor,
    required this.onChanged,
    required this.automationTarget,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final label = formatChannelPan(value);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 9),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 56,
          height: 20,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: accentColor,
              inactiveTrackColor: colors.surfaceContainerHighest,
              thumbColor: accentColor,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: ParameterInteractionWrapper<double>(
              parameterName: spec.name,
              value: value,
              defaultValue: spec.defaultValue,
              min: spec.min,
              max: spec.max,
              step: spec.step == 0.0 ? 0.01 : spec.step,
              onChanged: onChanged,
              onAddAutomation: () async {
                AppLogger.info(
                  "Create automation for ${spec.name} (ID: ${spec.id})",
                );
                ref
                    .read(automationProvider.notifier)
                    .handleAddAutomationForTarget(
                      target: automationTarget,
                      label: spec.name,
                      initialValue: value,
                    );
              },
              onRemoveAutomation: () {
                AppLogger.info(
                  "remove automation for ${spec.name} (ID: ${spec.id})",
                );
                ref
                    .read(automationProvider.notifier)
                    .handleRemoveAutomationForTarget(target: automationTarget);
              },
              child: DigidawParameterKnob(
                value: value,
                min: spec.min,
                max: spec.max,
                defaultValue: spec.defaultValue,
                step: spec.step == 0.0 ? 0.01 : spec.step,
                diameter: 30.0, // Perfectly sized for the 72px channel strip
                activeColor: accentColor,
                inactiveColor: colors.surfaceContainerHighest,
                onChanged: onChanged,
                onChangeStart: onChangeStart != null
                    ? (_) => onChangeStart!()
                    : null,
                onChangeEnd: onChangeEnd != null ? (_) => onChangeEnd!() : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// Volume Fader
// =========================================================

class _VolumeFader extends ConsumerWidget {
  final double value;
  final ParameterSpecDTO spec;
  final Color accentColor;
  final AutomationTargetDto automationTarget;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  const _VolumeFader({
    required this.value,
    required this.spec,
    required this.accentColor,
    required this.automationTarget,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderWidth = constraints.maxHeight;

        // Ensure the visual slider stops at -60dB even if the internal `NEG_INFINITY` is lower
        final visualMin = spec.min < -100.0 ? -100.0 : spec.min;

        return RotatedBox(
          quarterTurns: 3,
          child: ParameterInteractionWrapper<double>(
            parameterName: spec.name,
            value: value,
            defaultValue: spec.defaultValue,
            min: visualMin,
            max: spec.max,
            step: spec.step == 0.0 ? 0.1 : spec.step,
            onChanged: onChanged,
            onAddAutomation: () async {
              AppLogger.info(
                "Create automation for ${spec.name} (ID: ${spec.id})",
              );
              ref
                  .read(automationProvider.notifier)
                  .handleAddAutomationForTarget(
                    target: automationTarget,
                    label: spec.name,
                    initialValue: value,
                  );
            },
            onRemoveAutomation: () async {
              AppLogger.info(
                "Remove automation for ${spec.name} (ID: ${spec.id})",
              );
              ref
                  .read(automationProvider.notifier)
                  .handleRemoveAutomationForTarget(target: automationTarget);
            },
            child: SizedBox(
              width: sliderWidth,
              height: constraints.maxWidth,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  activeTrackColor: accentColor,
                  inactiveTrackColor: colors.surfaceContainerHighest,
                  thumbColor: accentColor,
                  overlayColor: accentColor.withValues(alpha: 0.15),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: DigidawParameterSlider(
                  color: accentColor,
                  slider: Slider(
                    value: value.clamp(visualMin, spec.max),
                    min: visualMin,
                    max: spec.max,
                    onChanged: onChanged,
                    allowedInteraction: SliderInteraction.slideThumb,
                    onChangeStart: onChangeStart != null
                        ? (_) => onChangeStart!()
                        : null,
                    onChangeEnd: onChangeEnd != null
                        ? (_) => onChangeEnd!()
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
