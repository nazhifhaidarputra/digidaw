// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'crash_recovery_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CrashRecoveryState {

 bool get previousSessionUnclean; UiRecoveryInfo? get recovery; IList<UiCrashReportSummary> get crashReports; bool get isBusy;
/// Create a copy of CrashRecoveryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CrashRecoveryStateCopyWith<CrashRecoveryState> get copyWith => _$CrashRecoveryStateCopyWithImpl<CrashRecoveryState>(this as CrashRecoveryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CrashRecoveryState&&(identical(other.previousSessionUnclean, previousSessionUnclean) || other.previousSessionUnclean == previousSessionUnclean)&&(identical(other.recovery, recovery) || other.recovery == recovery)&&const DeepCollectionEquality().equals(other.crashReports, crashReports)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy));
}


@override
int get hashCode => Object.hash(runtimeType,previousSessionUnclean,recovery,const DeepCollectionEquality().hash(crashReports),isBusy);

@override
String toString() {
  return 'CrashRecoveryState(previousSessionUnclean: $previousSessionUnclean, recovery: $recovery, crashReports: $crashReports, isBusy: $isBusy)';
}


}

/// @nodoc
abstract mixin class $CrashRecoveryStateCopyWith<$Res>  {
  factory $CrashRecoveryStateCopyWith(CrashRecoveryState value, $Res Function(CrashRecoveryState) _then) = _$CrashRecoveryStateCopyWithImpl;
@useResult
$Res call({
 bool previousSessionUnclean, UiRecoveryInfo? recovery, IList<UiCrashReportSummary> crashReports, bool isBusy
});


$UiRecoveryInfoCopyWith<$Res>? get recovery;

}
/// @nodoc
class _$CrashRecoveryStateCopyWithImpl<$Res>
    implements $CrashRecoveryStateCopyWith<$Res> {
  _$CrashRecoveryStateCopyWithImpl(this._self, this._then);

  final CrashRecoveryState _self;
  final $Res Function(CrashRecoveryState) _then;

/// Create a copy of CrashRecoveryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? previousSessionUnclean = null,Object? recovery = freezed,Object? crashReports = null,Object? isBusy = null,}) {
  return _then(_self.copyWith(
previousSessionUnclean: null == previousSessionUnclean ? _self.previousSessionUnclean : previousSessionUnclean // ignore: cast_nullable_to_non_nullable
as bool,recovery: freezed == recovery ? _self.recovery : recovery // ignore: cast_nullable_to_non_nullable
as UiRecoveryInfo?,crashReports: null == crashReports ? _self.crashReports : crashReports // ignore: cast_nullable_to_non_nullable
as IList<UiCrashReportSummary>,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of CrashRecoveryState
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


/// Adds pattern-matching-related methods to [CrashRecoveryState].
extension CrashRecoveryStatePatterns on CrashRecoveryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CrashRecoveryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CrashRecoveryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CrashRecoveryState value)  $default,){
final _that = this;
switch (_that) {
case _CrashRecoveryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CrashRecoveryState value)?  $default,){
final _that = this;
switch (_that) {
case _CrashRecoveryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool previousSessionUnclean,  UiRecoveryInfo? recovery,  IList<UiCrashReportSummary> crashReports,  bool isBusy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CrashRecoveryState() when $default != null:
return $default(_that.previousSessionUnclean,_that.recovery,_that.crashReports,_that.isBusy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool previousSessionUnclean,  UiRecoveryInfo? recovery,  IList<UiCrashReportSummary> crashReports,  bool isBusy)  $default,) {final _that = this;
switch (_that) {
case _CrashRecoveryState():
return $default(_that.previousSessionUnclean,_that.recovery,_that.crashReports,_that.isBusy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool previousSessionUnclean,  UiRecoveryInfo? recovery,  IList<UiCrashReportSummary> crashReports,  bool isBusy)?  $default,) {final _that = this;
switch (_that) {
case _CrashRecoveryState() when $default != null:
return $default(_that.previousSessionUnclean,_that.recovery,_that.crashReports,_that.isBusy);case _:
  return null;

}
}

}

/// @nodoc


class _CrashRecoveryState extends CrashRecoveryState {
  const _CrashRecoveryState({this.previousSessionUnclean = false, this.recovery, this.crashReports = const IListConst([]), this.isBusy = false}): super._();
  

@override@JsonKey() final  bool previousSessionUnclean;
@override final  UiRecoveryInfo? recovery;
@override@JsonKey() final  IList<UiCrashReportSummary> crashReports;
@override@JsonKey() final  bool isBusy;

/// Create a copy of CrashRecoveryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CrashRecoveryStateCopyWith<_CrashRecoveryState> get copyWith => __$CrashRecoveryStateCopyWithImpl<_CrashRecoveryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CrashRecoveryState&&(identical(other.previousSessionUnclean, previousSessionUnclean) || other.previousSessionUnclean == previousSessionUnclean)&&(identical(other.recovery, recovery) || other.recovery == recovery)&&const DeepCollectionEquality().equals(other.crashReports, crashReports)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy));
}


@override
int get hashCode => Object.hash(runtimeType,previousSessionUnclean,recovery,const DeepCollectionEquality().hash(crashReports),isBusy);

@override
String toString() {
  return 'CrashRecoveryState(previousSessionUnclean: $previousSessionUnclean, recovery: $recovery, crashReports: $crashReports, isBusy: $isBusy)';
}


}

/// @nodoc
abstract mixin class _$CrashRecoveryStateCopyWith<$Res> implements $CrashRecoveryStateCopyWith<$Res> {
  factory _$CrashRecoveryStateCopyWith(_CrashRecoveryState value, $Res Function(_CrashRecoveryState) _then) = __$CrashRecoveryStateCopyWithImpl;
@override @useResult
$Res call({
 bool previousSessionUnclean, UiRecoveryInfo? recovery, IList<UiCrashReportSummary> crashReports, bool isBusy
});


@override $UiRecoveryInfoCopyWith<$Res>? get recovery;

}
/// @nodoc
class __$CrashRecoveryStateCopyWithImpl<$Res>
    implements _$CrashRecoveryStateCopyWith<$Res> {
  __$CrashRecoveryStateCopyWithImpl(this._self, this._then);

  final _CrashRecoveryState _self;
  final $Res Function(_CrashRecoveryState) _then;

/// Create a copy of CrashRecoveryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? previousSessionUnclean = null,Object? recovery = freezed,Object? crashReports = null,Object? isBusy = null,}) {
  return _then(_CrashRecoveryState(
previousSessionUnclean: null == previousSessionUnclean ? _self.previousSessionUnclean : previousSessionUnclean // ignore: cast_nullable_to_non_nullable
as bool,recovery: freezed == recovery ? _self.recovery : recovery // ignore: cast_nullable_to_non_nullable
as UiRecoveryInfo?,crashReports: null == crashReports ? _self.crashReports : crashReports // ignore: cast_nullable_to_non_nullable
as IList<UiCrashReportSummary>,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of CrashRecoveryState
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
