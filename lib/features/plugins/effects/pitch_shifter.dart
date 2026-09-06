import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/plugins/abstract_plugin_screen.dart';

class DigidawPitchShifter extends AbstractPluginScreen {
  const DigidawPitchShifter({super.key, required super.target});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => DigidawPitcherState();
}

class DigidawPitcherState
    extends AbstractPluginScreenState<DigidawPitchShifter> {
  @override
  String get pluginName => 'Digidaw Pitcher';
}
