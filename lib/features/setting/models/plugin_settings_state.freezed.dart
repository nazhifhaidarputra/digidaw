// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginSettingsState {

 bool get isInitialized; IList<String> get defaultDirectories; IList<String> get directories; int get timeoutSeconds; bool get isSaving; bool get isScanning; bool get isCancelling; int? get scanId; int get completed; int get total; String? get currentPath; int get discoveredCount; bool get hasCompletedScan; bool get lastScanCancelled; String? get scanError; IList<UiPluginScanFailure> get failures; IList<UiExternalPluginEntry> get externalPlugins;
/// Create a copy of PluginSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSettingsStateCopyWith<PluginSettingsState> get copyWith => _$PluginSettingsStateCopyWithImpl<PluginSettingsState>(this as PluginSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSettingsState&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&const DeepCollectionEquality().equals(other.defaultDirectories, defaultDirectories)&&const DeepCollectionEquality().equals(other.directories, directories)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&(identical(other.isScanning, isScanning) || other.isScanning == isScanning)&&(identical(other.isCancelling, isCancelling) || other.isCancelling == isCancelling)&&(identical(other.scanId, scanId) || other.scanId == scanId)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.total, total) || other.total == total)&&(identical(other.currentPath, currentPath) || other.currentPath == currentPath)&&(identical(other.discoveredCount, discoveredCount) || other.discoveredCount == discoveredCount)&&(identical(other.hasCompletedScan, hasCompletedScan) || other.hasCompletedScan == hasCompletedScan)&&(identical(other.lastScanCancelled, lastScanCancelled) || other.lastScanCancelled == lastScanCancelled)&&(identical(other.scanError, scanError) || other.scanError == scanError)&&const DeepCollectionEquality().equals(other.failures, failures)&&const DeepCollectionEquality().equals(other.externalPlugins, externalPlugins));
}


@override
int get hashCode => Object.hash(runtimeType,isInitialized,const DeepCollectionEquality().hash(defaultDirectories),const DeepCollectionEquality().hash(directories),timeoutSeconds,isSaving,isScanning,isCancelling,scanId,completed,total,currentPath,discoveredCount,hasCompletedScan,lastScanCancelled,scanError,const DeepCollectionEquality().hash(failures),const DeepCollectionEquality().hash(externalPlugins));

@override
String toString() {
  return 'PluginSettingsState(isInitialized: $isInitialized, defaultDirectories: $defaultDirectories, directories: $directories, timeoutSeconds: $timeoutSeconds, isSaving: $isSaving, isScanning: $isScanning, isCancelling: $isCancelling, scanId: $scanId, completed: $completed, total: $total, currentPath: $currentPath, discoveredCount: $discoveredCount, hasCompletedScan: $hasCompletedScan, lastScanCancelled: $lastScanCancelled, scanError: $scanError, failures: $failures, externalPlugins: $externalPlugins)';
}


}

/// @nodoc
abstract mixin class $PluginSettingsStateCopyWith<$Res>  {
  factory $PluginSettingsStateCopyWith(PluginSettingsState value, $Res Function(PluginSettingsState) _then) = _$PluginSettingsStateCopyWithImpl;
@useResult
$Res call({
 bool isInitialized, IList<String> defaultDirectories, IList<String> directories, int timeoutSeconds, bool isSaving, bool isScanning, bool isCancelling, int? scanId, int completed, int total, String? currentPath, int discoveredCount, bool hasCompletedScan, bool lastScanCancelled, String? scanError, IList<UiPluginScanFailure> failures, IList<UiExternalPluginEntry> externalPlugins
});




}
/// @nodoc
class _$PluginSettingsStateCopyWithImpl<$Res>
    implements $PluginSettingsStateCopyWith<$Res> {
  _$PluginSettingsStateCopyWithImpl(this._self, this._then);

  final PluginSettingsState _self;
  final $Res Function(PluginSettingsState) _then;

/// Create a copy of PluginSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isInitialized = null,Object? defaultDirectories = null,Object? directories = null,Object? timeoutSeconds = null,Object? isSaving = null,Object? isScanning = null,Object? isCancelling = null,Object? scanId = freezed,Object? completed = null,Object? total = null,Object? currentPath = freezed,Object? discoveredCount = null,Object? hasCompletedScan = null,Object? lastScanCancelled = null,Object? scanError = freezed,Object? failures = null,Object? externalPlugins = null,}) {
  return _then(_self.copyWith(
isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,defaultDirectories: null == defaultDirectories ? _self.defaultDirectories : defaultDirectories // ignore: cast_nullable_to_non_nullable
as IList<String>,directories: null == directories ? _self.directories : directories // ignore: cast_nullable_to_non_nullable
as IList<String>,timeoutSeconds: null == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,isScanning: null == isScanning ? _self.isScanning : isScanning // ignore: cast_nullable_to_non_nullable
as bool,isCancelling: null == isCancelling ? _self.isCancelling : isCancelling // ignore: cast_nullable_to_non_nullable
as bool,scanId: freezed == scanId ? _self.scanId : scanId // ignore: cast_nullable_to_non_nullable
as int?,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currentPath: freezed == currentPath ? _self.currentPath : currentPath // ignore: cast_nullable_to_non_nullable
as String?,discoveredCount: null == discoveredCount ? _self.discoveredCount : discoveredCount // ignore: cast_nullable_to_non_nullable
as int,hasCompletedScan: null == hasCompletedScan ? _self.hasCompletedScan : hasCompletedScan // ignore: cast_nullable_to_non_nullable
as bool,lastScanCancelled: null == lastScanCancelled ? _self.lastScanCancelled : lastScanCancelled // ignore: cast_nullable_to_non_nullable
as bool,scanError: freezed == scanError ? _self.scanError : scanError // ignore: cast_nullable_to_non_nullable
as String?,failures: null == failures ? _self.failures : failures // ignore: cast_nullable_to_non_nullable
as IList<UiPluginScanFailure>,externalPlugins: null == externalPlugins ? _self.externalPlugins : externalPlugins // ignore: cast_nullable_to_non_nullable
as IList<UiExternalPluginEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginSettingsState].
extension PluginSettingsStatePatterns on PluginSettingsState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginSettingsState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _PluginSettingsState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _PluginSettingsState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isInitialized,  IList<String> defaultDirectories,  IList<String> directories,  int timeoutSeconds,  bool isSaving,  bool isScanning,  bool isCancelling,  int? scanId,  int completed,  int total,  String? currentPath,  int discoveredCount,  bool hasCompletedScan,  bool lastScanCancelled,  String? scanError,  IList<UiPluginScanFailure> failures,  IList<UiExternalPluginEntry> externalPlugins)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginSettingsState() when $default != null:
return $default(_that.isInitialized,_that.defaultDirectories,_that.directories,_that.timeoutSeconds,_that.isSaving,_that.isScanning,_that.isCancelling,_that.scanId,_that.completed,_that.total,_that.currentPath,_that.discoveredCount,_that.hasCompletedScan,_that.lastScanCancelled,_that.scanError,_that.failures,_that.externalPlugins);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isInitialized,  IList<String> defaultDirectories,  IList<String> directories,  int timeoutSeconds,  bool isSaving,  bool isScanning,  bool isCancelling,  int? scanId,  int completed,  int total,  String? currentPath,  int discoveredCount,  bool hasCompletedScan,  bool lastScanCancelled,  String? scanError,  IList<UiPluginScanFailure> failures,  IList<UiExternalPluginEntry> externalPlugins)  $default,) {final _that = this;
switch (_that) {
case _PluginSettingsState():
return $default(_that.isInitialized,_that.defaultDirectories,_that.directories,_that.timeoutSeconds,_that.isSaving,_that.isScanning,_that.isCancelling,_that.scanId,_that.completed,_that.total,_that.currentPath,_that.discoveredCount,_that.hasCompletedScan,_that.lastScanCancelled,_that.scanError,_that.failures,_that.externalPlugins);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isInitialized,  IList<String> defaultDirectories,  IList<String> directories,  int timeoutSeconds,  bool isSaving,  bool isScanning,  bool isCancelling,  int? scanId,  int completed,  int total,  String? currentPath,  int discoveredCount,  bool hasCompletedScan,  bool lastScanCancelled,  String? scanError,  IList<UiPluginScanFailure> failures,  IList<UiExternalPluginEntry> externalPlugins)?  $default,) {final _that = this;
switch (_that) {
case _PluginSettingsState() when $default != null:
return $default(_that.isInitialized,_that.defaultDirectories,_that.directories,_that.timeoutSeconds,_that.isSaving,_that.isScanning,_that.isCancelling,_that.scanId,_that.completed,_that.total,_that.currentPath,_that.discoveredCount,_that.hasCompletedScan,_that.lastScanCancelled,_that.scanError,_that.failures,_that.externalPlugins);case _:
  return null;

}
}

}

/// @nodoc


class _PluginSettingsState extends PluginSettingsState {
  const _PluginSettingsState({this.isInitialized = false, this.defaultDirectories = const IListConst<String>([]), this.directories = const IListConst<String>([]), this.timeoutSeconds = 30, this.isSaving = false, this.isScanning = false, this.isCancelling = false, this.scanId, this.completed = 0, this.total = 0, this.currentPath, this.discoveredCount = 0, this.hasCompletedScan = false, this.lastScanCancelled = false, this.scanError, this.failures = const IListConst<UiPluginScanFailure>([]), this.externalPlugins = const IListConst<UiExternalPluginEntry>([])}): super._();
  

@override@JsonKey() final  bool isInitialized;
@override@JsonKey() final  IList<String> defaultDirectories;
@override@JsonKey() final  IList<String> directories;
@override@JsonKey() final  int timeoutSeconds;
@override@JsonKey() final  bool isSaving;
@override@JsonKey() final  bool isScanning;
@override@JsonKey() final  bool isCancelling;
@override final  int? scanId;
@override@JsonKey() final  int completed;
@override@JsonKey() final  int total;
@override final  String? currentPath;
@override@JsonKey() final  int discoveredCount;
@override@JsonKey() final  bool hasCompletedScan;
@override@JsonKey() final  bool lastScanCancelled;
@override final  String? scanError;
@override@JsonKey() final  IList<UiPluginScanFailure> failures;
@override@JsonKey() final  IList<UiExternalPluginEntry> externalPlugins;

/// Create a copy of PluginSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSettingsStateCopyWith<_PluginSettingsState> get copyWith => __$PluginSettingsStateCopyWithImpl<_PluginSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSettingsState&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&const DeepCollectionEquality().equals(other.defaultDirectories, defaultDirectories)&&const DeepCollectionEquality().equals(other.directories, directories)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&(identical(other.isScanning, isScanning) || other.isScanning == isScanning)&&(identical(other.isCancelling, isCancelling) || other.isCancelling == isCancelling)&&(identical(other.scanId, scanId) || other.scanId == scanId)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.total, total) || other.total == total)&&(identical(other.currentPath, currentPath) || other.currentPath == currentPath)&&(identical(other.discoveredCount, discoveredCount) || other.discoveredCount == discoveredCount)&&(identical(other.hasCompletedScan, hasCompletedScan) || other.hasCompletedScan == hasCompletedScan)&&(identical(other.lastScanCancelled, lastScanCancelled) || other.lastScanCancelled == lastScanCancelled)&&(identical(other.scanError, scanError) || other.scanError == scanError)&&const DeepCollectionEquality().equals(other.failures, failures)&&const DeepCollectionEquality().equals(other.externalPlugins, externalPlugins));
}


@override
int get hashCode => Object.hash(runtimeType,isInitialized,const DeepCollectionEquality().hash(defaultDirectories),const DeepCollectionEquality().hash(directories),timeoutSeconds,isSaving,isScanning,isCancelling,scanId,completed,total,currentPath,discoveredCount,hasCompletedScan,lastScanCancelled,scanError,const DeepCollectionEquality().hash(failures),const DeepCollectionEquality().hash(externalPlugins));

@override
String toString() {
  return 'PluginSettingsState(isInitialized: $isInitialized, defaultDirectories: $defaultDirectories, directories: $directories, timeoutSeconds: $timeoutSeconds, isSaving: $isSaving, isScanning: $isScanning, isCancelling: $isCancelling, scanId: $scanId, completed: $completed, total: $total, currentPath: $currentPath, discoveredCount: $discoveredCount, hasCompletedScan: $hasCompletedScan, lastScanCancelled: $lastScanCancelled, scanError: $scanError, failures: $failures, externalPlugins: $externalPlugins)';
}


}

/// @nodoc
abstract mixin class _$PluginSettingsStateCopyWith<$Res> implements $PluginSettingsStateCopyWith<$Res> {
  factory _$PluginSettingsStateCopyWith(_PluginSettingsState value, $Res Function(_PluginSettingsState) _then) = __$PluginSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 bool isInitialized, IList<String> defaultDirectories, IList<String> directories, int timeoutSeconds, bool isSaving, bool isScanning, bool isCancelling, int? scanId, int completed, int total, String? currentPath, int discoveredCount, bool hasCompletedScan, bool lastScanCancelled, String? scanError, IList<UiPluginScanFailure> failures, IList<UiExternalPluginEntry> externalPlugins
});




}
/// @nodoc
class __$PluginSettingsStateCopyWithImpl<$Res>
    implements _$PluginSettingsStateCopyWith<$Res> {
  __$PluginSettingsStateCopyWithImpl(this._self, this._then);

  final _PluginSettingsState _self;
  final $Res Function(_PluginSettingsState) _then;

/// Create a copy of PluginSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isInitialized = null,Object? defaultDirectories = null,Object? directories = null,Object? timeoutSeconds = null,Object? isSaving = null,Object? isScanning = null,Object? isCancelling = null,Object? scanId = freezed,Object? completed = null,Object? total = null,Object? currentPath = freezed,Object? discoveredCount = null,Object? hasCompletedScan = null,Object? lastScanCancelled = null,Object? scanError = freezed,Object? failures = null,Object? externalPlugins = null,}) {
  return _then(_PluginSettingsState(
isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,defaultDirectories: null == defaultDirectories ? _self.defaultDirectories : defaultDirectories // ignore: cast_nullable_to_non_nullable
as IList<String>,directories: null == directories ? _self.directories : directories // ignore: cast_nullable_to_non_nullable
as IList<String>,timeoutSeconds: null == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,isScanning: null == isScanning ? _self.isScanning : isScanning // ignore: cast_nullable_to_non_nullable
as bool,isCancelling: null == isCancelling ? _self.isCancelling : isCancelling // ignore: cast_nullable_to_non_nullable
as bool,scanId: freezed == scanId ? _self.scanId : scanId // ignore: cast_nullable_to_non_nullable
as int?,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currentPath: freezed == currentPath ? _self.currentPath : currentPath // ignore: cast_nullable_to_non_nullable
as String?,discoveredCount: null == discoveredCount ? _self.discoveredCount : discoveredCount // ignore: cast_nullable_to_non_nullable
as int,hasCompletedScan: null == hasCompletedScan ? _self.hasCompletedScan : hasCompletedScan // ignore: cast_nullable_to_non_nullable
as bool,lastScanCancelled: null == lastScanCancelled ? _self.lastScanCancelled : lastScanCancelled // ignore: cast_nullable_to_non_nullable
as bool,scanError: freezed == scanError ? _self.scanError : scanError // ignore: cast_nullable_to_non_nullable
as String?,failures: null == failures ? _self.failures : failures // ignore: cast_nullable_to_non_nullable
as IList<UiPluginScanFailure>,externalPlugins: null == externalPlugins ? _self.externalPlugins : externalPlugins // ignore: cast_nullable_to_non_nullable
as IList<UiExternalPluginEntry>,
  ));
}


}

// dart format on
