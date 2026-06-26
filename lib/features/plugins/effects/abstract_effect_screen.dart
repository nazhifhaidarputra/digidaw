import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/daw_stream_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/widgets/plugin_parameter_widget.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/src/rust/api/project.dart';

/// Abstract base class for effect plugin screens.
///
/// Provides default implementations for:
/// - Parameter polling (from audio thread feedback)
/// - Loading parameter specs
/// - Setting parameters (optimistic UI + backend)
/// - Standard Scaffold/AppBar layout
/// - Automatic Dynamic UI Generation based on Rust #[param] specs
///
/// Subclasses can override [buildEffectBody] to define a custom effect UI,
/// but it defaults to an automatically generated layout.
abstract class AbstractEffectScreen extends ConsumerStatefulWidget {
  final plugin_api.UiEffectTarget target;
  final int effectId;

  const AbstractEffectScreen({super.key, required this.target, required this.effectId});
}

abstract class AbstractEffectScreenState<T extends AbstractEffectScreen> extends ConsumerState<T> {
  List<plugin_api.UiPluginParameter> parameters = [];
  bool isLoading = true;
  String? errorMessage;

  DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;

  /// Display name for the effect (shown in AppBar).
  /// Override this in subclasses to customize.
  String get effectName => 'Effect';

  /// Helper getter to automatically group parameters by their Rust `group` string.
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
    loadParameterSpecs();
    _requestParameterFeedback();
  }

  /// Start polling for parameter feedback from the audio thread.
  @protected
  void _requestParameterFeedback() async {
    try {
      // Just tell Rust we are watching this effect.
      // The stream will handle the actual data delivery.
      await plugin_api.queryEffectParameters(ctx: _ctx, target: widget.target, effectId: widget.effectId);
    } catch (e) {
      debugPrint('Failed to request effect parameters: $e');
    }
  }

  /// Load parameter specs from the backend.
  @protected
  Future<void> loadParameterSpecs() async {
    try {
      final specs = await plugin_api.getEffectParameterSpecs(
        ctx: _ctx,
        target: widget.target,
        effectId: widget.effectId,
      );
      setState(() {
        // Sort parameters by ID to maintain a consistent UI order
        specs.sort((a, b) => a.id.compareTo(b.id));
        parameters = specs;
        isLoading = false;
      });
      onParametersUpdated();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load effect parameters: $e';
        isLoading = false;
      });
    }
  }

  /// Reset a parameter to its default value.
  @protected
  Future<void> resetToDefault({required int paramId}) async {
    await plugin_api.setEffectParameter(
      ctx: _ctx,
      target: widget.target,
      effectId: widget.effectId,
      paramId: plugin_api.UiParamId.id(paramId),
      value: parameters[paramId].defaultValue,
    );
  }

  /// Set a parameter value with optimistic local update + backend sync.
  @protected
  Future<void> setParameter(int paramId, double value) async {
    // Update local state immediately for smooth UI
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

    // Send to backend
    try {
      await plugin_api.setEffectParameter(
        ctx: _ctx,
        target: widget.target,
        effectId: widget.effectId,
        paramId: plugin_api.UiParamId.id(paramId),
        value: value,
      );
    } catch (e) {
      debugPrint('Error setting effect parameter: $e');
    }
  }

  @protected
  double getParameter(int paramId, double fallback) {
    try {
      return parameters.firstWhere((p) => p.id == paramId).value;
    } catch (e) {
      return fallback;
    }
  }

  @protected
  Future<void> setParameterString(String paramId, double value) async {
    setState(() {
      final index = parameters.indexWhere((p) => p.path == paramId);
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

    // Send to backend
    try {
      await plugin_api.setEffectParameter(
        ctx: _ctx,
        target: widget.target,
        effectId: widget.effectId,
        paramId: plugin_api.UiParamId.path(paramId),
        value: value,
      );
    } catch (e) {
      debugPrint('Error setting effect parameter: $e');
    }
  }

  @protected
  double getParameterString(String paramId, double fallback) {
    try {
      return parameters.firstWhere((p) => p.path == paramId).value;
    } catch (e) {
      return fallback;
    }
  }

  /// Called when parameters are updated from backend or polling.
  @protected
  void onParametersUpdated() {}

  /// Signals the engine that a human is starting to manipulate this parameter.
  @protected
  void beginParameterEdit(int paramId) {
    try {
      plugin_api.beginEffectParameterEdit(
        ctx: _ctx,
        effectTarget: widget.target,
        effectId: widget.effectId,
        paramId: plugin_api.UiParamId.id(paramId),
      );
    } catch (e) {
      debugPrint('Error beginning effect parameter edit: $e');
    }
  }

  /// Signals the engine that the human has stopped manipulating this parameter.
  @protected
  void endParameterEdit(int paramId) {
    try {
      plugin_api.endEffectParameterEdit(
        ctx: _ctx,
        effectTarget: widget.target,
        effectId: widget.effectId,
        paramId: plugin_api.UiParamId.id(paramId),
      );
    } catch (e) {
      debugPrint('Error ending effect parameter edit: $e');
    }
  }

  // ==========================================================================
  // DYNAMIC UI GENERATION
  // ==========================================================================

  /// Builds a fully automatic UI based on the Rust ParameterSpecs.
  Widget buildDynamicEffectBody(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
              _buildSectionHeader(entry.key), // The group name
              _buildSectionContainer(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entry.value.map((param) {
                    return Padding(padding: const EdgeInsets.only(bottom: 16), child: buildParameterWidget(param));
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

  /// Automatically routes the parameter to the correct universal widget.
  /// Subclasses can override this to inject custom UI for specific parameters.
  @protected
  Widget buildParameterWidget(plugin_api.UiPluginParameter param) {
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
        );
      case plugin_api.UiParameterType.choice:
        return DawChoiceParam(
          paramId: param.id,
          name: param.name,
          value: param.value,
          choices: param.choices,
          defaultValue: param.defaultValue,
          onChanged: (val) {
            // Instantaneous sequence for dropdowns
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
            // Instantaneous sequence for toggles
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
        style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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

  /// Subclasses can override this to provide a custom UI layout,
  /// but it defaults to the dynamic layout.
  Widget buildEffectBody(BuildContext context) {
    return buildDynamicEffectBody(context);
  }

  @protected
  void initParameterListener() {
    ref.listen(masterAudioFeedbackProvider, (previous, next) {
      if (!next.hasValue || next.value == null) return;

      final feedback = next.value!;

      // Helper to verify this stream event belongs to THIS specific effect widget
      bool isMatchingTarget(int? streamTrackId, int? streamBusId) {
        if (widget.target is plugin_api.UiEffectTarget_Track) {
          return streamTrackId == (widget.target as plugin_api.UiEffectTarget_Track).field0;
        } else if (widget.target is plugin_api.UiEffectTarget_Bus) {
          return streamBusId == (widget.target as plugin_api.UiEffectTarget_Bus).field0;
        } else if (widget.target is plugin_api.UiEffectTarget_Master) {
          return streamTrackId == null && streamBusId == null;
        }
        return false;
      }

      feedback.maybeWhen(
        // 1. Handle Bulk Parameter Snapshots
        effectParameterSnapshot: (targetTrackId, targetBusId, snapshotEffectId, snapshotParams) {
          if (snapshotEffectId != widget.effectId ||
              !isMatchingTarget(targetTrackId, targetBusId) ||
              snapshotParams.isEmpty)
            return;

          setState(() {
            for (final paramTuple in snapshotParams) {
              final paramId = paramTuple.$1;
              final paramValue = paramTuple.$2;

              final index = parameters.indexWhere((p) => p.id == paramId);
              if (index != -1) {
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
              }
            }
          });
          onParametersUpdated();
        },

        // 2. Handle Single Parameter Changes
        effectParameterChanged: (targetTrackId, targetBusId, changedEffectId, paramId, value) {
          if (changedEffectId != widget.effectId || !isMatchingTarget(targetTrackId, targetBusId)) return;

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
        },

        // 3. Ignore Generator, Mixer, and other events
        orElse: () {},
      );
    });
  }

  @protected
  Scaffold buildScaffold(Widget body) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(effectName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    initParameterListener();
    return buildScaffold(buildEffectBody(context));
  }
}
