import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/track/models/automation_curve_template.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

/// Stores automation curve templates in the user's settings, so every project
/// on this computer shares one library. Rust skips stored templates that are
/// damaged, so one bad entry does not hide the rest of the library.
class AutomationTemplateService {
  Future<Result<IList<AutomationCurveTemplate>>> load() {
    return attemptAsync(
      () async => (await settings_api.loadAutomationTemplates())
          .map(_fromStored)
          .toIList(),
    );
  }

  Future<Result<void>> save(IList<AutomationCurveTemplate> templates) {
    return attemptAsync(
      () => settings_api.saveAutomationTemplates(
        templates: templates.map(_toStored).toList(),
      ),
    );
  }
}

AutomationCurveTemplate _fromStored(settings_api.UiAutomationTemplate stored) {
  return AutomationCurveTemplate(
    id: stored.id,
    name: stored.name,
    lengthTicks: stored.lengthTicks,
    points: stored.points.lock,
  );
}

settings_api.UiAutomationTemplate _toStored(AutomationCurveTemplate template) {
  return settings_api.UiAutomationTemplate(
    id: template.id,
    name: template.name,
    lengthTicks: template.lengthTicks,
    points: template.points.unlock,
  );
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
