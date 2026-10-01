import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/track/models/automation_curve_template.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores automation curve templates in the user's preferences, so every
/// project on this computer shares one library.
class AutomationTemplateService {
  static const storageKey = 'automation.curve_templates.v1';

  Future<Result<IList<AutomationCurveTemplate>>> load() {
    return attemptAsync(() async {
      final stored =
          await SharedPreferencesAsync().getStringList(storageKey) ?? const [];
      return decodeAutomationTemplates(stored);
    });
  }

  Future<Result<void>> save(IList<AutomationCurveTemplate> templates) {
    return attemptAsync(
      () => SharedPreferencesAsync().setStringList(
        storageKey,
        encodeAutomationTemplates(templates),
      ),
    );
  }
}

/// Encodes each template as one JSON document.
List<String> encodeAutomationTemplates(
  Iterable<AutomationCurveTemplate> templates,
) => [
  for (final template in templates)
    jsonEncode({
      'id': template.id,
      'name': template.name,
      'lengthTicks': template.lengthTicks,
      'points': [
        for (final point in template.points)
          {
            'timeTicks': point.timeTicks,
            'value': point.value,
            'curveType': point.curveType.name,
            'tension': point.tension,
            if (point.handles case final handles?)
              'handles': [handles.x1, handles.y1, handles.x2, handles.y2],
          },
      ],
    }),
];

/// Decodes stored templates. Entries that are not valid templates are
/// skipped, so one damaged entry does not hide the rest of the library.
IList<AutomationCurveTemplate> decodeAutomationTemplates(
  Iterable<String> stored,
) => stored.map(_decodeTemplate).nonNulls.toIList();

AutomationCurveTemplate? _decodeTemplate(String source) {
  final Object? json = attempt(() => jsonDecode(source)).unwrapOr(null);
  if (json case {
    'id': final String id,
    'name': final String name,
    'lengthTicks': final int lengthTicks,
    'points': final List<Object?> points,
  }) {
    final decoded = points.map(_decodePoint).toIList();
    if (decoded.isEmpty || decoded.any((point) => point == null)) return null;
    return AutomationCurveTemplate(
      id: id,
      name: name,
      lengthTicks: lengthTicks,
      points: decoded.nonNulls.toIList(),
    );
  }
  return null;
}

AutomationPointDto? _decodePoint(Object? json) {
  if (json case {
    'timeTicks': final int timeTicks,
    'value': final num value,
    'curveType': final String curveName,
    'tension': final num tension,
  }) {
    final curveType = AutomationCurveTypeDto.values
        .where((curve) => curve.name == curveName)
        .firstOrNull;
    if (curveType == null) return null;
    return AutomationPointDto(
      // Pasting assigns real identifiers.
      id: 0,
      timeTicks: timeTicks,
      value: value.toDouble(),
      curveType: curveType,
      tension: tension.toDouble(),
      handles: switch (json['handles']) {
        [final num x1, final num y1, final num x2, final num y2] =>
          BezierHandlesDto(
            x1: x1.toDouble(),
            y1: y1.toDouble(),
            x2: x2.toDouble(),
            y2: y2.toDouble(),
          ),
        _ => null,
      },
    );
  }
  return null;
}

final automationTemplateServiceProvider = Provider<AutomationTemplateService>(
  (ref) => AutomationTemplateService(),
);

/// The user's automation curve template library.
class AutomationTemplatesNotifier
    extends AsyncNotifier<IList<AutomationCurveTemplate>> {
  @override
  Future<IList<AutomationCurveTemplate>> build() async {
    final loaded = await ref.read(automationTemplateServiceProvider).load();
    return switch (loaded) {
      Ok(:final value) => value,
      Error(:final error) => () {
        ref.notifyError(error);
        return const IListConst<AutomationCurveTemplate>([]);
      }(),
    };
  }

  /// Adds a template named [name] holding [points] of a [lengthTicks] range.
  Future<void> add({
    required String name,
    required int lengthTicks,
    required IList<AutomationPointDto> points,
  }) {
    final template = AutomationCurveTemplate(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      lengthTicks: lengthTicks,
      points: points,
    );
    return _store((templates) => templates.add(template));
  }

  Future<void> rename(String id, String name) => _store(
    (templates) =>
        templates.map((t) => t.id == id ? t.copyWith(name: name) : t).toIList(),
  );

  Future<void> remove(String id) =>
      _store((templates) => templates.removeWhere((t) => t.id == id));

  /// Applies [change] to the library and persists it; the visible library
  /// only changes once it is saved.
  Future<void> _store(
    IList<AutomationCurveTemplate> Function(
      IList<AutomationCurveTemplate> templates,
    )
    change,
  ) async {
    final current =
        state.value ?? const IListConst<AutomationCurveTemplate>([]);
    final next = change(current);
    final saved = await ref.read(automationTemplateServiceProvider).save(next);
    switch (saved) {
      case Ok():
        state = AsyncData(next);
      case Error(:final error):
        ref.notifyError(error);
    }
  }
}

final automationTemplatesProvider =
    AsyncNotifierProvider<
      AutomationTemplatesNotifier,
      IList<AutomationCurveTemplate>
    >(AutomationTemplatesNotifier.new);
