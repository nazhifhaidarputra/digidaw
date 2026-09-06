import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/plugins/abstract_plugin_screen.dart';

class DigidawDelay extends AbstractPluginScreen {
  const DigidawDelay({super.key, required super.target});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return DigidawDelayState();
  }
}

class DigidawDelayState extends AbstractPluginScreenState<DigidawDelay> {
  @override
  String get pluginName => 'Digidaw Delay';
}