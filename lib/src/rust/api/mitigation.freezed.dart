// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mitigation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiAutoSaveSettings {

 bool get isEnabled; int get intervalSeconds;
/// Create a copy of UiAutoSaveSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiAutoSaveSettingsCopyWith<UiAutoSaveSettings> get copyWith => _$UiAutoSaveSettingsCopyWithImpl<UiAutoSaveSettings>(this as UiAutoSaveSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiAutoSaveSettings&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.intervalSeconds, intervalSeconds) || other.intervalSeconds == intervalSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,isEnabled,intervalSeconds);

@override
String toString() {
  return 'UiAutoSaveSettings(isEnabled: $isEnabled, intervalSeconds: $intervalSeconds)';
}


}

/// @nodoc
abstract mixin class $UiAutoSaveSettingsCopyWith<$Res>  {
  factory $UiAutoSaveSettingsCopyWith(UiAutoSaveSettings value, $Res Function(UiAutoSaveSettings) _then) = _$UiAutoSaveSettingsCopyWithImpl;
@useResult
$Res call({
 bool isEnabled, int intervalSeconds
});




}
/// @nodoc
class _$UiAutoSaveSettingsCopyWithImpl<$Res>
    implements $UiAutoSaveSettingsCopyWith<$Res> {
  _$UiAutoSaveSettingsCopyWithImpl(this._self, this._then);

  final UiAutoSaveSettings _self;
  final $Res Function(UiAutoSaveSettings) _then;

/// Create a copy of UiAutoSaveSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isEnabled = null,Object? intervalSeconds = null,}) {
  return _then(_self.copyWith(
isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,intervalSeconds: null == intervalSeconds ? _self.intervalSeconds : intervalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiAutoSaveSettings].
extension UiAutoSaveSettingsPatterns on UiAutoSaveSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiAutoSaveSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiAutoSaveSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiAutoSaveSettings value)  $default,){
final _that = this;
switch (_that) {
case _UiAutoSaveSettings():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiAutoSaveSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UiAutoSaveSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isEnabled,  int intervalSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiAutoSaveSettings() when $default != null:
return $default(_that.isEnabled,_that.intervalSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isEnabled,  int intervalSeconds)  $default,) {final _that = this;
switch (_that) {
case _UiAutoSaveSettings():
return $default(_that.isEnabled,_that.intervalSeconds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isEnabled,  int intervalSeconds)?  $default,) {final _that = this;
switch (_that) {
case _UiAutoSaveSettings() when $default != null:
return $default(_that.isEnabled,_that.intervalSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _UiAutoSaveSettings implements UiAutoSaveSettings {
  const _UiAutoSaveSettings({required this.isEnabled, required this.intervalSeconds});
  

@override final  bool isEnabled;
@override final  int intervalSeconds;

/// Create a copy of UiAutoSaveSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiAutoSaveSettingsCopyWith<_UiAutoSaveSettings> get copyWith => __$UiAutoSaveSettingsCopyWithImpl<_UiAutoSaveSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiAutoSaveSettings&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.intervalSeconds, intervalSeconds) || other.intervalSeconds == intervalSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,isEnabled,intervalSeconds);

@override
String toString() {
  return 'UiAutoSaveSettings(isEnabled: $isEnabled, intervalSeconds: $intervalSeconds)';
}


}

/// @nodoc
abstract mixin class _$UiAutoSaveSettingsCopyWith<$Res> implements $UiAutoSaveSettingsCopyWith<$Res> {
  factory _$UiAutoSaveSettingsCopyWith(_UiAutoSaveSettings value, $Res Function(_UiAutoSaveSettings) _then) = __$UiAutoSaveSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool isEnabled, int intervalSeconds
});




}
/// @nodoc
class __$UiAutoSaveSettingsCopyWithImpl<$Res>
    implements _$UiAutoSaveSettingsCopyWith<$Res> {
  __$UiAutoSaveSettingsCopyWithImpl(this._self, this._then);

  final _UiAutoSaveSettings _self;
  final $Res Function(_UiAutoSaveSettings) _then;

/// Create a copy of UiAutoSaveSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isEnabled = null,Object? intervalSeconds = null,}) {
  return _then(_UiAutoSaveSettings(
isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,intervalSeconds: null == intervalSeconds ? _self.intervalSeconds : intervalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiCrashReportSummary {

 String get id; int get code; String get summary; int get occurredAtMillis; String get appVersion;
/// Create a copy of UiCrashReportSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiCrashReportSummaryCopyWith<UiCrashReportSummary> get copyWith => _$UiCrashReportSummaryCopyWithImpl<UiCrashReportSummary>(this as UiCrashReportSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiCrashReportSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.occurredAtMillis, occurredAtMillis) || other.occurredAtMillis == occurredAtMillis)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,summary,occurredAtMillis,appVersion);

@override
String toString() {
  return 'UiCrashReportSummary(id: $id, code: $code, summary: $summary, occurredAtMillis: $occurredAtMillis, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class $UiCrashReportSummaryCopyWith<$Res>  {
  factory $UiCrashReportSummaryCopyWith(UiCrashReportSummary value, $Res Function(UiCrashReportSummary) _then) = _$UiCrashReportSummaryCopyWithImpl;
@useResult
$Res call({
 String id, int code, String summary, int occurredAtMillis, String appVersion
});




}
/// @nodoc
class _$UiCrashReportSummaryCopyWithImpl<$Res>
    implements $UiCrashReportSummaryCopyWith<$Res> {
  _$UiCrashReportSummaryCopyWithImpl(this._self, this._then);

  final UiCrashReportSummary _self;
  final $Res Function(UiCrashReportSummary) _then;

/// Create a copy of UiCrashReportSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? summary = null,Object? occurredAtMillis = null,Object? appVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as int,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,occurredAtMillis: null == occurredAtMillis ? _self.occurredAtMillis : occurredAtMillis // ignore: cast_nullable_to_non_nullable
as int,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiCrashReportSummary].
extension UiCrashReportSummaryPatterns on UiCrashReportSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiCrashReportSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiCrashReportSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiCrashReportSummary value)  $default,){
final _that = this;
switch (_that) {
case _UiCrashReportSummary():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiCrashReportSummary value)?  $default,){
final _that = this;
switch (_that) {
case _UiCrashReportSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int code,  String summary,  int occurredAtMillis,  String appVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiCrashReportSummary() when $default != null:
return $default(_that.id,_that.code,_that.summary,_that.occurredAtMillis,_that.appVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int code,  String summary,  int occurredAtMillis,  String appVersion)  $default,) {final _that = this;
switch (_that) {
case _UiCrashReportSummary():
return $default(_that.id,_that.code,_that.summary,_that.occurredAtMillis,_that.appVersion);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int code,  String summary,  int occurredAtMillis,  String appVersion)?  $default,) {final _that = this;
switch (_that) {
case _UiCrashReportSummary() when $default != null:
return $default(_that.id,_that.code,_that.summary,_that.occurredAtMillis,_that.appVersion);case _:
  return null;

}
}

}

/// @nodoc


class _UiCrashReportSummary implements UiCrashReportSummary {
  const _UiCrashReportSummary({required this.id, required this.code, required this.summary, required this.occurredAtMillis, required this.appVersion});
  

@override final  String id;
@override final  int code;
@override final  String summary;
@override final  int occurredAtMillis;
@override final  String appVersion;

/// Create a copy of UiCrashReportSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiCrashReportSummaryCopyWith<_UiCrashReportSummary> get copyWith => __$UiCrashReportSummaryCopyWithImpl<_UiCrashReportSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiCrashReportSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.occurredAtMillis, occurredAtMillis) || other.occurredAtMillis == occurredAtMillis)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,summary,occurredAtMillis,appVersion);

@override
String toString() {
  return 'UiCrashReportSummary(id: $id, code: $code, summary: $summary, occurredAtMillis: $occurredAtMillis, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class _$UiCrashReportSummaryCopyWith<$Res> implements $UiCrashReportSummaryCopyWith<$Res> {
  factory _$UiCrashReportSummaryCopyWith(_UiCrashReportSummary value, $Res Function(_UiCrashReportSummary) _then) = __$UiCrashReportSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, int code, String summary, int occurredAtMillis, String appVersion
});




}
/// @nodoc
class __$UiCrashReportSummaryCopyWithImpl<$Res>
    implements _$UiCrashReportSummaryCopyWith<$Res> {
  __$UiCrashReportSummaryCopyWithImpl(this._self, this._then);

  final _UiCrashReportSummary _self;
  final $Res Function(_UiCrashReportSummary) _then;

/// Create a copy of UiCrashReportSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? summary = null,Object? occurredAtMillis = null,Object? appVersion = null,}) {
  return _then(_UiCrashReportSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as int,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,occurredAtMillis: null == occurredAtMillis ? _self.occurredAtMillis : occurredAtMillis // ignore: cast_nullable_to_non_nullable
as int,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiRecoveryInfo {

 String get projectName; String? get originalPath; int get savedAtMillis;
/// Create a copy of UiRecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiRecoveryInfoCopyWith<UiRecoveryInfo> get copyWith => _$UiRecoveryInfoCopyWithImpl<UiRecoveryInfo>(this as UiRecoveryInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRecoveryInfo&&(identical(other.projectName, projectName) || other.projectName == projectName)&&(identical(other.originalPath, originalPath) || other.originalPath == originalPath)&&(identical(other.savedAtMillis, savedAtMillis) || other.savedAtMillis == savedAtMillis));
}


@override
int get hashCode => Object.hash(runtimeType,projectName,originalPath,savedAtMillis);

@override
String toString() {
  return 'UiRecoveryInfo(projectName: $projectName, originalPath: $originalPath, savedAtMillis: $savedAtMillis)';
}


}

/// @nodoc
abstract mixin class $UiRecoveryInfoCopyWith<$Res>  {
  factory $UiRecoveryInfoCopyWith(UiRecoveryInfo value, $Res Function(UiRecoveryInfo) _then) = _$UiRecoveryInfoCopyWithImpl;
@useResult
$Res call({
 String projectName, String? originalPath, int savedAtMillis
});




}
/// @nodoc
class _$UiRecoveryInfoCopyWithImpl<$Res>
    implements $UiRecoveryInfoCopyWith<$Res> {
  _$UiRecoveryInfoCopyWithImpl(this._self, this._then);

  final UiRecoveryInfo _self;
  final $Res Function(UiRecoveryInfo) _then;

/// Create a copy of UiRecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectName = null,Object? originalPath = freezed,Object? savedAtMillis = null,}) {
  return _then(_self.copyWith(
projectName: null == projectName ? _self.projectName : projectName // ignore: cast_nullable_to_non_nullable
as String,originalPath: freezed == originalPath ? _self.originalPath : originalPath // ignore: cast_nullable_to_non_nullable
as String?,savedAtMillis: null == savedAtMillis ? _self.savedAtMillis : savedAtMillis // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiRecoveryInfo].
extension UiRecoveryInfoPatterns on UiRecoveryInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiRecoveryInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiRecoveryInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiRecoveryInfo value)  $default,){
final _that = this;
switch (_that) {
case _UiRecoveryInfo():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiRecoveryInfo value)?  $default,){
final _that = this;
switch (_that) {
case _UiRecoveryInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String projectName,  String? originalPath,  int savedAtMillis)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiRecoveryInfo() when $default != null:
return $default(_that.projectName,_that.originalPath,_that.savedAtMillis);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String projectName,  String? originalPath,  int savedAtMillis)  $default,) {final _that = this;
switch (_that) {
case _UiRecoveryInfo():
return $default(_that.projectName,_that.originalPath,_that.savedAtMillis);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String projectName,  String? originalPath,  int savedAtMillis)?  $default,) {final _that = this;
switch (_that) {
case _UiRecoveryInfo() when $default != null:
return $default(_that.projectName,_that.originalPath,_that.savedAtMillis);case _:
  return null;

}
}

}

/// @nodoc


class _UiRecoveryInfo implements UiRecoveryInfo {
  const _UiRecoveryInfo({required this.projectName, this.originalPath, required this.savedAtMillis});
  

@override final  String projectName;
@override final  String? originalPath;
@override final  int savedAtMillis;

/// Create a copy of UiRecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiRecoveryInfoCopyWith<_UiRecoveryInfo> get copyWith => __$UiRecoveryInfoCopyWithImpl<_UiRecoveryInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiRecoveryInfo&&(identical(other.projectName, projectName) || other.projectName == projectName)&&(identical(other.originalPath, originalPath) || other.originalPath == originalPath)&&(identical(other.savedAtMillis, savedAtMillis) || other.savedAtMillis == savedAtMillis));
}


@override
int get hashCode => Object.hash(runtimeType,projectName,originalPath,savedAtMillis);

@override
String toString() {
  return 'UiRecoveryInfo(projectName: $projectName, originalPath: $originalPath, savedAtMillis: $savedAtMillis)';
}


}

/// @nodoc
abstract mixin class _$UiRecoveryInfoCopyWith<$Res> implements $UiRecoveryInfoCopyWith<$Res> {
  factory _$UiRecoveryInfoCopyWith(_UiRecoveryInfo value, $Res Function(_UiRecoveryInfo) _then) = __$UiRecoveryInfoCopyWithImpl;
@override @useResult
$Res call({
 String projectName, String? originalPath, int savedAtMillis
});




}
/// @nodoc
class __$UiRecoveryInfoCopyWithImpl<$Res>
    implements _$UiRecoveryInfoCopyWith<$Res> {
  __$UiRecoveryInfoCopyWithImpl(this._self, this._then);

  final _UiRecoveryInfo _self;
  final $Res Function(_UiRecoveryInfo) _then;

/// Create a copy of UiRecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectName = null,Object? originalPath = freezed,Object? savedAtMillis = null,}) {
  return _then(_UiRecoveryInfo(
projectName: null == projectName ? _self.projectName : projectName // ignore: cast_nullable_to_non_nullable
as String,originalPath: freezed == originalPath ? _self.originalPath : originalPath // ignore: cast_nullable_to_non_nullable
as String?,savedAtMillis: null == savedAtMillis ? _self.savedAtMillis : savedAtMillis // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiStartupRecovery {

 bool get previousSessionUnclean; UiRecoveryInfo? get recovery; List<UiCrashReportSummary> get crashReports;
/// Create a copy of UiStartupRecovery
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiStartupRecoveryCopyWith<UiStartupRecovery> get copyWith => _$UiStartupRecoveryCopyWithImpl<UiStartupRecovery>(this as UiStartupRecovery, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiStartupRecovery&&(identical(other.previousSessionUnclean, previousSessionUnclean) || other.previousSessionUnclean == previousSessionUnclean)&&(identical(other.recovery, recovery) || other.recovery == recovery)&&const DeepCollectionEquality().equals(other.crashReports, crashReports));
}


@override
int get hashCode => Object.hash(runtimeType,previousSessionUnclean,recovery,const DeepCollectionEquality().hash(crashReports));

@override
String toString() {
  return 'UiStartupRecovery(previousSessionUnclean: $previousSessionUnclean, recovery: $recovery, crashReports: $crashReports)';
}


}

/// @nodoc
abstract mixin class $UiStartupRecoveryCopyWith<$Res>  {
  factory $UiStartupRecoveryCopyWith(UiStartupRecovery value, $Res Function(UiStartupRecovery) _then) = _$UiStartupRecoveryCopyWithImpl;
@useResult
$Res call({
 bool previousSessionUnclean, UiRecoveryInfo? recovery, List<UiCrashReportSummary> crashReports
});


$UiRecoveryInfoCopyWith<$Res>? get recovery;

}
/// @nodoc
class _$UiStartupRecoveryCopyWithImpl<$Res>
    implements $UiStartupRecoveryCopyWith<$Res> {
  _$UiStartupRecoveryCopyWithImpl(this._self, this._then);

  final UiStartupRecovery _self;
  final $Res Function(UiStartupRecovery) _then;

/// Create a copy of UiStartupRecovery
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? previousSessionUnclean = null,Object? recovery = freezed,Object? crashReports = null,}) {
  return _then(_self.copyWith(
previousSessionUnclean: null == previousSessionUnclean ? _self.previousSessionUnclean : previousSessionUnclean // ignore: cast_nullable_to_non_nullable
as bool,recovery: freezed == recovery ? _self.recovery : recovery // ignore: cast_nullable_to_non_nullable
as UiRecoveryInfo?,crashReports: null == crashReports ? _self.crashReports : crashReports // ignore: cast_nullable_to_non_nullable
as List<UiCrashReportSummary>,
  ));
}
/// Create a copy of UiStartupRecovery
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRecoveryInfoCopyWith<$Res>? get recovery {
    if (_self.recovery == null) {
    return null;
  }

  return $UiRecoveryInfoCopyWith<$Res>(_self.recovery!, (value) {
    return _then(_self.copyWith(recovery: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiStartupRecovery].
extension UiStartupRecoveryPatterns on UiStartupRecovery {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiStartupRecovery value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiStartupRecovery() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiStartupRecovery value)  $default,){
final _that = this;
switch (_that) {
case _UiStartupRecovery():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiStartupRecovery value)?  $default,){
final _that = this;
switch (_that) {
case _UiStartupRecovery() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool previousSessionUnclean,  UiRecoveryInfo? recovery,  List<UiCrashReportSummary> crashReports)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiStartupRecovery() when $default != null:
return $default(_that.previousSessionUnclean,_that.recovery,_that.crashReports);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool previousSessionUnclean,  UiRecoveryInfo? recovery,  List<UiCrashReportSummary> crashReports)  $default,) {final _that = this;
switch (_that) {
case _UiStartupRecovery():
return $default(_that.previousSessionUnclean,_that.recovery,_that.crashReports);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool previousSessionUnclean,  UiRecoveryInfo? recovery,  List<UiCrashReportSummary> crashReports)?  $default,) {final _that = this;
switch (_that) {
case _UiStartupRecovery() when $default != null:
return $default(_that.previousSessionUnclean,_that.recovery,_that.crashReports);case _:
  return null;

}
}

}

/// @nodoc


class _UiStartupRecovery implements UiStartupRecovery {
  const _UiStartupRecovery({required this.previousSessionUnclean, this.recovery, required final  List<UiCrashReportSummary> crashReports}): _crashReports = crashReports;
  

@override final  bool previousSessionUnclean;
@override final  UiRecoveryInfo? recovery;
 final  List<UiCrashReportSummary> _crashReports;
@override List<UiCrashReportSummary> get crashReports {
  if (_crashReports is EqualUnmodifiableListView) return _crashReports;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_crashReports);
}


/// Create a copy of UiStartupRecovery
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiStartupRecoveryCopyWith<_UiStartupRecovery> get copyWith => __$UiStartupRecoveryCopyWithImpl<_UiStartupRecovery>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiStartupRecovery&&(identical(other.previousSessionUnclean, previousSessionUnclean) || other.previousSessionUnclean == previousSessionUnclean)&&(identical(other.recovery, recovery) || other.recovery == recovery)&&const DeepCollectionEquality().equals(other._crashReports, _crashReports));
}


@override
int get hashCode => Object.hash(runtimeType,previousSessionUnclean,recovery,const DeepCollectionEquality().hash(_crashReports));

@override
String toString() {
  return 'UiStartupRecovery(previousSessionUnclean: $previousSessionUnclean, recovery: $recovery, crashReports: $crashReports)';
}


}

/// @nodoc
abstract mixin class _$UiStartupRecoveryCopyWith<$Res> implements $UiStartupRecoveryCopyWith<$Res> {
  factory _$UiStartupRecoveryCopyWith(_UiStartupRecovery value, $Res Function(_UiStartupRecovery) _then) = __$UiStartupRecoveryCopyWithImpl;
@override @useResult
$Res call({
 bool previousSessionUnclean, UiRecoveryInfo? recovery, List<UiCrashReportSummary> crashReports
});


@override $UiRecoveryInfoCopyWith<$Res>? get recovery;

}
/// @nodoc
class __$UiStartupRecoveryCopyWithImpl<$Res>
    implements _$UiStartupRecoveryCopyWith<$Res> {
  __$UiStartupRecoveryCopyWithImpl(this._self, this._then);

  final _UiStartupRecovery _self;
  final $Res Function(_UiStartupRecovery) _then;

/// Create a copy of UiStartupRecovery
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? previousSessionUnclean = null,Object? recovery = freezed,Object? crashReports = null,}) {
  return _then(_UiStartupRecovery(
previousSessionUnclean: null == previousSessionUnclean ? _self.previousSessionUnclean : previousSessionUnclean // ignore: cast_nullable_to_non_nullable
as bool,recovery: freezed == recovery ? _self.recovery : recovery // ignore: cast_nullable_to_non_nullable
as UiRecoveryInfo?,crashReports: null == crashReports ? _self._crashReports : crashReports // ignore: cast_nullable_to_non_nullable
as List<UiCrashReportSummary>,
  ));
}

/// Create a copy of UiStartupRecovery
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRecoveryInfoCopyWith<$Res>? get recovery {
    if (_self.recovery == null) {
    return null;
  }

  return $UiRecoveryInfoCopyWith<$Res>(_self.recovery!, (value) {
    return _then(_self.copyWith(recovery: value));
  });
}
}

// dart format on
