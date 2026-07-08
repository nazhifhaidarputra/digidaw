

import 'package:karbeat/features/plugins/abstract_plugin_screen.dart';

class MyRetroSynth extends AbstractPluginScreen {
  const MyRetroSynth({super.key, required super.target});

  @override
  MyRetroSynthState createState() => MyRetroSynthState();
}

class MyRetroSynthState extends AbstractPluginScreenState<MyRetroSynth> {
  @override
  String get pluginName => 'MyRetro Synth';
}
