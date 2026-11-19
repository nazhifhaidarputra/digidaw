import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/widgets/digidaw_plugin_widgets/widgets.dart';
import 'package:karbeat/core/widgets/plugin_parameter_widget.dart';
import 'package:karbeat/features/plugins/abstract_plugin_screen.dart';
import 'package:karbeat/generated/plugins/stereo_shaper.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;

/// Stereo Shaper: source routing, mid/side image, mono bass, Haas delay and
/// balance, laid out as one section per stage of the signal path.
class DigidawStereoShaper extends AbstractPluginScreen {
  const DigidawStereoShaper({super.key, required super.target});

  @override
  ConsumerState<DigidawStereoShaper> createState() =>
      DigidawStereoShaperState();
}

class DigidawStereoShaperState
    extends AbstractPluginScreenState<DigidawStereoShaper> {
  @override
  String get pluginName => DigidawStereoShaperSpecs.name;

  plugin_api.UiPluginParameter _live(plugin_api.UiPluginParameter generated) {
    return parameters.firstWhere(
      (parameter) => parameter.id == generated.id,
      orElse: () => generated,
    );
  }

  Widget _knob(plugin_api.UiPluginParameter generated, {String suffix = ''}) {
    final parameter = _live(generated);
    return SizedBox(
      width: 112,
      child: DawFloatParam(
        paramId: parameter.id,
        name: parameter.name,
        value: parameter.value,
        min: parameter.min,
        max: parameter.max,
        defaultValue: parameter.defaultValue,
        step: parameter.step,
        suffix: suffix,
        controlStyle: DawControlStyle.knob,
        knobDiameter: 52,
        onChanged: (value) => setParameter(parameter.id, value),
        onChangeStart: (_) => beginParameterEdit(parameter.id),
        onChangeEnd: (_) => endParameterEdit(parameter.id),
        target: resolveAutomationTarget(parameter.id),
      ),
    );
  }

  /// Bool and choice parameters, drawn by the shared parameter widget.
  Widget _control(plugin_api.UiPluginParameter generated) {
    return SizedBox(
      width: 200,
      child: buildDynamicParameterWidget(_live(generated)),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildPluginBody(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Text(
          errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    final sections = [
      _section(context, tr('plugins-section-input'), [
        _control(DigidawStereoShaperSpecs.source),
        _control(DigidawStereoShaperSpecs.invertLeft),
        _control(DigidawStereoShaperSpecs.invertRight),
      ]),
      _section(context, tr('plugins-section-stereo-image'), [
        _knob(DigidawStereoShaperSpecs.width),
        _knob(DigidawStereoShaperSpecs.midDb, suffix: ' dB'),
        _knob(DigidawStereoShaperSpecs.sideDb, suffix: ' dB'),
        _knob(DigidawStereoShaperSpecs.rotation, suffix: '°'),
      ]),
      _section(context, tr('plugins-section-bass-space'), [
        _control(DigidawStereoShaperSpecs.bassMono),
        _knob(DigidawStereoShaperSpecs.bassMonoHz, suffix: ' Hz'),
        _knob(DigidawStereoShaperSpecs.haasMs, suffix: ' ms'),
      ]),
      _section(context, tr('plugins-section-output'), [
        _knob(DigidawStereoShaperSpecs.balance),
        _knob(DigidawStereoShaperSpecs.outputDb, suffix: ' dB'),
      ]),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final (index, section) in sections.indexed) ...[
            if (index > 0) const SizedBox(height: 16),
            section,
          ],
        ],
      ),
    );
  }
}
