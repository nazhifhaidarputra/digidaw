import 'dart:convert';
import 'dart:io';

import 'package:karbeat/core/utils/logger.dart';

void main() {
  final inputDir = Directory('assets/manifests/audio-plugins');
  final outputDir = Directory('lib/generated/plugins');

  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Find all JSON files in the directory recursively
  final files = inputDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'));

  final List<String> generatedClasses = [];

  for (final file in files) {
    final jsonStr = file.readAsStringSync();
    final Map<String, dynamic> manifest = jsonDecode(jsonStr);

    if (manifest['internal_type'] == null || manifest['id_string'] == null) {
      AppLogger.info('Skipping ${file.path} - Not a valid plugin manifest');
      continue;
    }

    final className = manifest['internal_type'] as String;
    final fileName = (manifest['id_string'] as String)
        .replaceAll('synth_', '')
        .replaceAll('effect_', '');

    final generatedCode = _generateDartClass(className, manifest);

    final outputFile = File('${outputDir.path}/$fileName.dart');
    outputFile.writeAsStringSync(generatedCode);

    generatedClasses.add(fileName);
    AppLogger.info('Generated: ${outputFile.path}');
  }

  // Create an index barrel file for easy importing
  final barrelFile = File('${outputDir.path}/plugins.dart');
  final barrelContent = generatedClasses
      .map((f) => "export '$f.dart';")
      .join('\n');
  barrelFile.writeAsStringSync(barrelContent);

  AppLogger.info(
    '✅ Successfully generated ${generatedClasses.length} plugin manifests.',
  );
}

String _generateDartClass(String className, Map<String, dynamic> manifest) {
  final parameters = manifest['parameters'] as List<dynamic>;

  final buffer = StringBuffer();
  buffer.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  buffer.writeln("// Source: ${manifest['id_string']}");
  buffer.writeln("");
  buffer.writeln("import 'package:karbeat/src/rust/api/plugin.dart';");
  buffer.writeln("");

  // Generate the Static Specs Class (Compile-time extraction)
  buffer.writeln("class ${className}Specs {");
  buffer.writeln("  static const int id = ${manifest['id']};");
  buffer.writeln(
    "  static const String idString = '${manifest['id_string']}';",
  );
  buffer.writeln("  static const String name = '${manifest['name']}';");
  buffer.writeln("  static const bool isSynth = ${manifest['is_synth']};");
  buffer.writeln("");

  for (final p in parameters) {
    final path = p['path'] as String;
    final paramName = _toCamelCase(path.replaceAll('/', '_'));
    final choices = (p['choices'] as List).map((c) => "'$c'").toList();

    buffer.writeln(
      "  static const UiPluginParameter $paramName = UiPluginParameter(",
    );
    buffer.writeln("    id: ${p['id']},");
    buffer.writeln("    path: '${p['path']}',");
    buffer.writeln("    name: '${p['name']}',");
    buffer.writeln("    group: '${p['group']}',");
    buffer.writeln("    value: ${p['value']},");
    buffer.writeln("    min: ${p['min']},");
    buffer.writeln("    max: ${p['max']},");
    buffer.writeln("    defaultValue: ${p['default_value']},");
    buffer.writeln("    step: ${p['step']},");
    buffer.writeln(
      "    paramType: UiParameterType.${(p['value_type'] as String).toLowerCase()},",
    );
    buffer.writeln("    choices: [${choices.join(', ')}],");
    buffer.writeln("  );");
    buffer.writeln("");
  }

  // Create a list of all parameters for easy iteration
  final allParams = parameters
      .map((p) => _toCamelCase((p['path'] as String).replaceAll('/', '_')))
      .join(', ');
  buffer.writeln(
    "  static const List<UiPluginParameter> allParameters = [$allParams];",
  );
  buffer.writeln("}");

  return buffer.toString();
}

String _toCamelCase(String text) {
  final words = text.split(RegExp(r'[_-]'));
  if (words.isEmpty) return '';
  final first = words.first.toLowerCase();
  final rest = words
      .skip(1)
      .map(
        (w) => w.substring(0, 1).toUpperCase() + w.substring(1).toLowerCase(),
      );
  return '$first${rest.join('')}';
}
