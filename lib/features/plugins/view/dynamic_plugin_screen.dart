import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/features/plugins/generators/abstract_generator_screen.dart';
import 'package:karbeat/features/piano_roll/view/scrollable_virtual_keyboard.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;

/// Generic Dynamic Plugin Screen that generates UI from plugin parameter specs.
/// This acts as a fallback for generators that do not have custom UI.
class DynamicPluginScreen extends AbstractGeneratorScreen {
  final String _generatorName;

  const DynamicPluginScreen({
    super.key,
    required super.generatorId,
    required String generatorName,
  }) : _generatorName = generatorName;

  @override
  ConsumerState<DynamicPluginScreen> createState() =>
      _DynamicPluginScreenState();
}

class _DynamicPluginScreenState
    extends AbstractGeneratorScreenState<DynamicPluginScreen> {
  // Track active notes for keyboard visualization
  final Set<int> _activeNotes = {};

  @override
  String get generatorName => widget._generatorName;

  @override
  Widget buildGeneratorBody(BuildContext context) {
    return Column(
      children: [
        Expanded(child: super.buildDynamicGeneratorBody(context)),
        // Scrollable MIDI Keyboard
        ScrollableVirtualKeyboard(
          height: 120,
          onNoteOn: _handleNoteOn,
          onNoteOff: _handleNoteOff,
          activeNotes: _activeNotes,
          initialCenterNote: 72,
        ),
      ],
    );
  }

  void _handleNoteOn(int note) async {
    setState(() => _activeNotes.add(note));
    try {
      final ctx = ref.read(projectProvider.notifier).dawContext;
      await audio_api.playPreviewNoteGenerator(
        ctx: ctx,
        generatorId: widget.generatorId,
        noteKey: note,
        velocity: 100,
        isOn: true,
      );
    } catch (e) {
      AppLogger.error('Error playing note on: $e');
    }
  }

  void _handleNoteOff(int note) async {
    setState(() => _activeNotes.remove(note));
    try {
      final ctx = ref.read(projectProvider.notifier).dawContext;
      await audio_api.playPreviewNoteGenerator(
        ctx: ctx,
        generatorId: widget.generatorId,
        noteKey: note,
        velocity: 100,
        isOn: false,
      );
    } catch (e) {
      AppLogger.error('Error playing note off: $e');
    }
  }
}
