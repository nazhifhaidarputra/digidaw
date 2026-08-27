// import 'package:flutter_riverpod/fl';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/plugins/abstract_plugin_screen.dart';

class DigidawPitcher extends AbstractPluginScreen {
  const DigidawPitcher({super.key, required super.target});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => DigidawPitcherState();
}

class DigidawPitcherState extends AbstractPluginScreenState<DigidawPitcher> {
  @override
  String get pluginName => 'Digidaw Pitcher';
}
