import 'package:karbeat/features/plugins/generators/abstract_generator_screen.dart';

class MyRetroSynth extends AbstractGeneratorScreen {
  const MyRetroSynth({super.key, required super.generatorId});

  @override
  MyRetroSynthState createState() => MyRetroSynthState();
}

class MyRetroSynthState extends AbstractGeneratorScreenState<MyRetroSynth> {
  @override
  String get generatorName => 'MyRetro Synth';
}
