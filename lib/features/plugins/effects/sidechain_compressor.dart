import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/widgets/digidaw_plugin_widgets/widgets.dart';
import 'package:karbeat/core/widgets/plugin_parameter_widget.dart';
import 'package:karbeat/features/plugins/abstract_plugin_screen.dart';
import 'package:karbeat/features/plugins/widgets/sidechain_source_panel.dart';
import 'package:karbeat/generated/plugins/digidaw_sidechain_comp.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;

class DigidawSidechainCompressor extends AbstractPluginScreen {
  const DigidawSidechainCompressor({super.key, required super.target});

  @override
  ConsumerState<DigidawSidechainCompressor> createState() =>
      DigidawSidechainCompressorState();
}

class DigidawSidechainCompressorState
    extends AbstractPluginScreenState<DigidawSidechainCompressor> {
  @override
  String get pluginName => DigidawSidechainCompressorSpecs.name;

  plugin_api.UiPluginParameter _live(plugin_api.UiPluginParameter generated) {
    return parameters.firstWhere(
      (parameter) => parameter.id == generated.id,
      orElse: () => generated,
    );
  }

  Widget _knob(plugin_api.UiPluginParameter generated, {String suffix = ''}) {
    final parameter = _live(generated);
    return SizedBox(
      width: 132,
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
        knobDiameter: 58,
        onChanged: (value) => setParameter(parameter.id, value),
        onChangeStart: (_) => beginParameterEdit(parameter.id),
        onChangeEnd: (_) => endParameterEdit(parameter.id),
        target: resolveAutomationTarget(parameter.id),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 18, runSpacing: 20, children: children),
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
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    final channelMode = _live(DigidawSidechainCompressorSpecs.channelMode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final routingPanel = SidechainSourcePanel(target: widget.target);
        final dynamics = _section('DYNAMICS', [
          _knob(
            DigidawSidechainCompressorSpecs.compressorThreshold,
            suffix: ' dB',
          ),
          _knob(DigidawSidechainCompressorSpecs.compressorRatio, suffix: ':1'),
          _knob(
            DigidawSidechainCompressorSpecs.compressorAttack,
            suffix: ' ms',
          ),
          _knob(
            DigidawSidechainCompressorSpecs.compressorRelease,
            suffix: ' ms',
          ),
          _knob(DigidawSidechainCompressorSpecs.compressorKnee, suffix: ' dB'),
        ]);
        final output = _section('OUTPUT & TIMING', [
          _knob(
            DigidawSidechainCompressorSpecs.compressorMakeupGain,
            suffix: ' dB',
          ),
          _knob(DigidawSidechainCompressorSpecs.compressorDelay, suffix: ' ms'),
          _knob(DigidawSidechainCompressorSpecs.compressorWetMix),
          _knob(DigidawSidechainCompressorSpecs.compressorDryMix),
          SizedBox(width: 230, child: buildDynamicParameterWidget(channelMode)),
        ]);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 310, child: routingPanel),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          dynamics,
                          const SizedBox(height: 16),
                          output,
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    routingPanel,
                    const SizedBox(height: 16),
                    dynamics,
                    const SizedBox(height: 16),
                    output,
                  ],
                ),
        );
      },
    );
  }
}
