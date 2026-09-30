import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/mitigation.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

part 'crash_recovery_provider.freezed.dart';

/// What the previous run left behind: an auto saved copy to recover and crash
/// reports to review. Published once after startup, then cleared as the user
/// handles each item.
@freezed
abstract class CrashRecoveryState with _$CrashRecoveryState {
  const CrashRecoveryState._();

  const factory CrashRecoveryState({
    @Default(false) bool previousSessionUnclean,

    /// The previous run was ended on request, such as by Ctrl+C. Not a crash,
    /// so it only needs attention when it left an auto saved copy behind.
    @Default(false) bool previousSessionForced,
    UiRecoveryInfo? recovery,
    @Default(IListConst([])) IList<UiCrashReportSummary> crashReports,
    @Default(false) bool isBusy,
  }) = _CrashRecoveryState;

  bool get needsAttention =>
      previousSessionUnclean || recovery != null || crashReports.isNotEmpty;
}

class CrashRecoveryNotifier extends Notifier<CrashRecoveryState> {
  bool _initializationStarted = false;

  @override
  CrashRecoveryState build() => const CrashRecoveryState();

  /// Configures crash reporting and auto save under the application-support
  /// directory, then publishes what the previous run left behind.
  Future<Result<void>> initialize(DawContext context) async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;

    final supportDir = await attemptAsync(getApplicationSupportDirectory);
    if (supportDir case Error(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Crash recovery is unavailable',
      );
    }

    final configured = await attemptAsync(
      () async => configureMitigation(
        ctx: context,
        supportDir: supportDir.ok().path,
        appVersion: await _appVersion(),
      ),
    );
    if (configured case Error(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Crash recovery is unavailable',
      );
    }

    final startup = configured.ok();
    state = CrashRecoveryState(
      previousSessionUnclean: startup.previousSessionUnclean,
      previousSessionForced: startup.previousSessionForced,
      recovery: startup.recovery,
      crashReports: startup.crashReports.lock,
    );
    return Result.ok(null);
  }

  Future<String> _appVersion() async {
    final info = await attemptAsync(PackageInfo.fromPlatform);
    if (info case Ok(value: final info)) {
      return '${info.version}+${info.buildNumber}';
    }
    AppLogger.warn(
      'App version is unavailable for crash reports: ${info.err()}',
    );
    return 'unknown';
  }

  /// Replaces the current project with the auto saved copy.
  Future<Result<void>> recover() async {
    final recovery = state.recovery;
    if (recovery == null || state.isBusy) return Result.ok(null);

    state = state.copyWith(isBusy: true);
    final recovered = await ref
        .read(projectProvider.notifier)
        .loadRecoveredProject(recovery.originalPath);
    state = state.copyWith(
      isBusy: false,
      recovery: recovered.isOk() ? null : recovery,
    );
    return recovered;
  }

  /// Deletes the auto saved copy.
  Future<Result<void>> discardRecovery() async {
    final context = ref.read(projectProvider.notifier).dawContext;
    final discarded = await attemptAsync(
      () => discardRecoveredProject(ctx: context),
    );
    if (discarded case Error(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not discard the recovered project',
      );
    }
    state = state.copyWith(recovery: null);
    return Result.ok(null);
  }

  /// Copies one crash report's JSON to [destination].
  Future<Result<void>> exportReport(String id, String destination) async {
    final exported = await attemptAsync(
      () => exportCrashReport(id: id, destination: destination),
    );
    if (exported case Error(error: final error)) {
      return ref.notifyErrorResult(error, title: 'Could not export the report');
    }
    ref
        .read(notificationProvider.notifier)
        .info('Crash report exported to $destination', title: 'Report saved');
    return Result.ok(null);
  }

  /// Deletes every listed crash report.
  Future<Result<void>> dismissReports() async {
    for (final report in state.crashReports) {
      final removed = await attemptAsync(
        () => removeCrashReport(id: report.id),
      );
      if (removed case Error(error: final error)) {
        return ref.notifyErrorResult(
          error,
          title: 'Could not delete crash reports',
        );
      }
      state = state.copyWith(crashReports: state.crashReports.remove(report));
    }
    state = state.copyWith(previousSessionUnclean: false);
    return Result.ok(null);
  }

  /// Hides the prompt for this session without deleting anything.
  void dismiss() {
    state = const CrashRecoveryState();
  }
}

final crashRecoveryProvider =
    NotifierProvider<CrashRecoveryNotifier, CrashRecoveryState>(
      CrashRecoveryNotifier.new,
    );
