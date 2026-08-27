import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/widgets/plugin_parameter_widget.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/src/rust/api/plugins/opaque.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Unified abstract base class for BOTH Generators and Effects.
/// Handles 60 FPS synchronous telemetry polling, dynamic UI generation, and parameter setting.
abstract class AbstractPluginScreen extends ConsumerStatefulWidget {
  /// The generic target (e.g. Generator(id), TrackEffect(trackId, effectId), etc.)
  final plugin_api.UiPluginTarget target;


  const AbstractPluginScreen({
    super.key,
    required this.target
  });
}

abstract class AbstractPluginScreenState<T extends AbstractPluginScreen> 
    extends ConsumerState<T> with SingleTickerProviderStateMixin {
  
  List<plugin_api.UiPluginParameter> parameters = [];
  bool isLoading = true;
  String? errorMessage;
  
  // Track parameters the user is currently dragging so we don't overwrite them with telemetry
  final Set<int> _touchedParams = {};

  late final Ticker _ticker;
  
  @protected
  late final DawContext ctx;

  String get pluginName => 'Plugin';

  Map<String, List<plugin_api.UiPluginParameter>> get groupedParameters {
    final map = <String, List<plugin_api.UiPluginParameter>>{};
    for (final param in parameters) {
      if (!map.containsKey(param.group)) {
        map[param.group] = [];
      }
      map[param.group]!.add(param);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    ctx = ref.read(projectProvider.notifier).dawContext;
    _loadParameterSpecs();

    // Subscribe to the 30 FPS Rust Audio Engine stream for this specific plugin
    plugin_api.setPluginTelemetrySubs(
      ctx: ctx, 
      target: widget.target, 
      buffers: getRequestedZeroCopyBuffers(), 
      active: true,
    );

    // Start 60 FPS synchronous polling
    _ticker = createTicker((_) => _pollTelemetrySync());
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    
    // Unsubscribe from telemetry to save CPU when UI is closed
    plugin_api.setPluginTelemetrySubs(
      ctx: ctx, 
      target: widget.target, 
      buffers: [], 
      active: false,
    );
    
    super.dispose();
  }

  /// Override this if your specific plugin needs zero-copy buffers (e.g. "spectrum", "magnitude")
  @protected
  List<String> getRequestedZeroCopyBuffers() => [];

  /// Called automatically every frame to parse zero copy buffers (e.g. for EQ graphs)
  @protected
  void onZeroCopyBuffersReceived(Map<String, ZeroCopyHandle> buffers) {}

  /// The 60 FPS Heartbeat that synchronously fetches lock-free data from Rust
  void _pollTelemetrySync() {
    if (isLoading) return;

    // Instantly reads the ArcSwap pointer across the FFI boundary
    final telemetry = plugin_api.getPluginSnapshotTelemetrySync(ctx: ctx, target: widget.target);
    if (telemetry == null) return;

    bool paramsChanged = false;

    // 1. Update Parameters (Ignoring touched params)
    for (final paramTuple in telemetry.parameters) {
      final paramId = paramTuple.$1;
      final paramValue = paramTuple.$2;

      if (_touchedParams.contains(paramId)) continue;

      final index = parameters.indexWhere((p) => p.id == paramId);
      if (index != -1 && parameters[index].value != paramValue) {
        parameters[index] = plugin_api.UiPluginParameter(
          id: parameters[index].id,
          path: parameters[index].path,
          name: parameters[index].name,
          group: parameters[index].group,
          value: paramValue,
          min: parameters[index].min,
          max: parameters[index].max,
          defaultValue: parameters[index].defaultValue,
          step: parameters[index].step,
          paramType: parameters[index].paramType,
          choices: parameters[index].choices,
        );
        paramsChanged = true;
      }
    }

    if (paramsChanged) {
      setState(() {});
      onParametersUpdated();
    }

    // 2. Pass zero-copy buffers down to subclasses (e.g., Parametric EQ)
    if (telemetry.bufferHandles.isNotEmpty) {
      onZeroCopyBuffersReceived(telemetry.bufferHandles);
    }
  }

  Future<void> _loadParameterSpecs() async {
    try {
      final specs = await plugin_api.getPluginParameterSpecs(
        ctx: ctx,
        target: widget.target,
      );
      
      if (!mounted) return;
      
      setState(() {
        specs.sort((a, b) => a.id.compareTo(b.id));
        parameters = specs;
        isLoading = false;
      });
      onParametersUpdated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load plugin parameters: $e';
        isLoading = false;
      });
    }
  }

  @protected
  Future<void> setParameter(int paramId, double value) async {
    setState(() {
      final index = parameters.indexWhere((p) => p.id == paramId);
      if (index != -1) {
        parameters[index] = plugin_api.UiPluginParameter(
          id: parameters[index].id,
          path: parameters[index].path,
          name: parameters[index].name,
          group: parameters[index].group,
          value: value,
          min: parameters[index].min,
          max: parameters[index].max,
          defaultValue: parameters[index].defaultValue,
          step: parameters[index].step,
          paramType: parameters[index].paramType,
          choices: parameters[index].choices,
        );
      }
    });

    onParametersUpdated();

    try {
      await plugin_api.setPluginParameter(
        ctx: ctx,
        target: widget.target,
        paramId: plugin_api.UiParamId.id(paramId),
        value: value,
      );
    } catch (e) {
      AppLogger.error('Error setting plugin parameter: $e');
    }
  }

  @protected
  void beginParameterEdit(int paramId) {
    _touchedParams.add(paramId);
    try {
      plugin_api.beginPluginParameterEdit(
        ctx: ctx,
        target: widget.target,
        paramId: plugin_api.UiParamId.id(paramId),
      );
    } catch (e) {
      AppLogger.error('Error beginning edit: $e');
    }
  }

  @protected
  void endParameterEdit(int paramId) {
    _touchedParams.remove(paramId);
    try {
      plugin_api.endPluginParameterEdit(
        ctx: ctx,
        target: widget.target,
        paramId: plugin_api.UiParamId.id(paramId),
      );
    } catch (e) {
      AppLogger.error('Error ending edit: $e');
    }
  }

  @protected
  AutomationTargetDto resolveAutomationTarget(int paramId) {
    final t = widget.target;
    
    return switch (t) {
      plugin_api.UiPluginTarget_Generator(:final field0) =>
        AutomationTargetDto.generator(
          generatorId: field0,
          paramId: paramId,
        ),
        
      plugin_api.UiPluginTarget_TrackEffect(:final trackId, :final effectId) =>
        AutomationTargetDto.track(
          trackId: trackId,
          trackTarget: TrackAutomationTargetDto.mixerChannel(
            MixerChannelParamTargetDto.plugin(
              effectId: effectId,
              target: EffectAutomationTargetDto.pluginParam(paramId: paramId),
            ),
          ),
        ),
        
      plugin_api.UiPluginTarget_BusEffect(:final busId, :final effectId) =>
        AutomationTargetDto.bus(
          busId: busId,
          mixTarget: MixerChannelParamTargetDto.plugin(
            effectId: effectId,
            target: EffectAutomationTargetDto.pluginParam(paramId: paramId),
          ),
        ),
        
      plugin_api.UiPluginTarget_MasterEffect(:final field0) =>
        AutomationTargetDto.master(
          MasterAutomationTargetDto.mixerChannel(
            MixerChannelParamTargetDto.plugin(
              effectId: field0,
              target: EffectAutomationTargetDto.pluginParam(paramId: paramId),
            ),
          ),
        ),
        
      // _ => throw UnimplementedError("Unknown plugin target type: $t"),
    };
  }

  @protected
  void onParametersUpdated() {}

  // ==========================================================================
  // DYNAMIC UI GENERATION
  // ==========================================================================

  Widget buildDynamicPluginBody(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) {
      return Center(
        child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
      );
    }

    final groups = groupedParameters;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(entry.key),
              _buildSectionContainer(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entry.value.map((param) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: buildDynamicParameterWidget(param),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        }).toList(),
      ),
    );
  }

  @protected
  Widget buildDynamicParameterWidget(plugin_api.UiPluginParameter param) {
    final automationTarget = resolveAutomationTarget(param.id);

    switch (param.paramType) {
      case plugin_api.UiParameterType.float:
      case plugin_api.UiParameterType.int:
        return DawFloatParam(
          paramId: param.id,
          name: param.name,
          value: param.value,
          min: param.min,
          max: param.max,
          defaultValue: param.defaultValue,
          step: param.step == 0.0 ? 0.01 : param.step,
          onChanged: (val) => setParameter(param.id, val),
          onChangeStart: (_) => beginParameterEdit(param.id),
          onChangeEnd: (_) => endParameterEdit(param.id),
          target: automationTarget,
          sliderInteraction: SliderInteraction.tapAndSlide,
        );
      case plugin_api.UiParameterType.choice:
        return DawChoiceParam(
          paramId: param.id,
          name: param.name,
          value: param.value,
          choices: param.choices,
          defaultValue: param.defaultValue,
          onChanged: (val) {
            beginParameterEdit(param.id);
            setParameter(param.id, val);
            endParameterEdit(param.id);
          },
        );
      case plugin_api.UiParameterType.bool:
        return DawBoolParam(
          paramId: param.id,
          name: param.name,
          value: param.value,
          defaultValue: param.defaultValue,
          onChanged: (val) {
            beginParameterEdit(param.id);
            setParameter(param.id, val);
            endParameterEdit(param.id);
          },
        );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSectionContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700.withAlpha(128)),
      ),
      child: child,
    );
  }

  @protected
  Widget buildPluginBody(BuildContext context) {
    return buildDynamicPluginBody(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          pluginName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      body: buildPluginBody(context),
    );
  }
}