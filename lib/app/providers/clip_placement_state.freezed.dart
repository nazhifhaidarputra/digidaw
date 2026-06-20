// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clip_placement_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ClipPlacementState {

 int? get sourceId; UiSourceType? get sourceType; int get trackId; double get timeSamples;
/// Create a copy of ClipPlacementState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClipPlacementStateCopyWith<ClipPlacementState> get copyWith => _$ClipPlacementStateCopyWithImpl<ClipPlacementState>(this as ClipPlacementState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClipPlacementState&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.timeSamples, timeSamples) || other.timeSamples == timeSamples));
}


@override
int get hashCode => Object.hash(runtimeType,sourceId,sourceType,trackId,timeSamples);

@override
String toString() {
  return 'ClipPlacementState(sourceId: $sourceId, sourceType: $sourceType, trackId: $trackId, timeSamples: $timeSamples)';
}


}

/// @nodoc
abstract mixin class $ClipPlacementStateCopyWith<$Res>  {
  factory $ClipPlacementStateCopyWith(ClipPlacementState value, $Res Function(ClipPlacementState) _then) = _$ClipPlacementStateCopyWithImpl;
@useResult
$Res call({
 int? sourceId, UiSourceType? sourceType, int trackId, double timeSamples
});




}
/// @nodoc
class _$ClipPlacementStateCopyWithImpl<$Res>
    implements $ClipPlacementStateCopyWith<$Res> {
  _$ClipPlacementStateCopyWithImpl(this._self, this._then);

  final ClipPlacementState _self;
  final $Res Function(ClipPlacementState) _then;

/// Create a copy of ClipPlacementState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = freezed,Object? sourceType = freezed,Object? trackId = null,Object? timeSamples = null,}) {
  return _then(_self.copyWith(
sourceId: freezed == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int?,sourceType: freezed == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as UiSourceType?,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,timeSamples: null == timeSamples ? _self.timeSamples : timeSamples // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ClipPlacementState].
extension ClipPlacementStatePatterns on ClipPlacementState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClipPlacementState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClipPlacementState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClipPlacementState value)  $default,){
final _that = this;
switch (_that) {
case _ClipPlacementState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClipPlacementState value)?  $default,){
final _that = this;
switch (_that) {
case _ClipPlacementState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? sourceId,  UiSourceType? sourceType,  int trackId,  double timeSamples)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClipPlacementState() when $default != null:
return $default(_that.sourceId,_that.sourceType,_that.trackId,_that.timeSamples);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? sourceId,  UiSourceType? sourceType,  int trackId,  double timeSamples)  $default,) {final _that = this;
switch (_that) {
case _ClipPlacementState():
return $default(_that.sourceId,_that.sourceType,_that.trackId,_that.timeSamples);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? sourceId,  UiSourceType? sourceType,  int trackId,  double timeSamples)?  $default,) {final _that = this;
switch (_that) {
case _ClipPlacementState() when $default != null:
return $default(_that.sourceId,_that.sourceType,_that.trackId,_that.timeSamples);case _:
  return null;

}
}

}

/// @nodoc


class _ClipPlacementState implements ClipPlacementState {
  const _ClipPlacementState({this.sourceId, this.sourceType, this.trackId = -1, this.timeSamples = 0.0});
  

@override final  int? sourceId;
@override final  UiSourceType? sourceType;
@override@JsonKey() final  int trackId;
@override@JsonKey() final  double timeSamples;

/// Create a copy of ClipPlacementState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClipPlacementStateCopyWith<_ClipPlacementState> get copyWith => __$ClipPlacementStateCopyWithImpl<_ClipPlacementState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClipPlacementState&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.timeSamples, timeSamples) || other.timeSamples == timeSamples));
}


@override
int get hashCode => Object.hash(runtimeType,sourceId,sourceType,trackId,timeSamples);

@override
String toString() {
  return 'ClipPlacementState(sourceId: $sourceId, sourceType: $sourceType, trackId: $trackId, timeSamples: $timeSamples)';
}


}

/// @nodoc
abstract mixin class _$ClipPlacementStateCopyWith<$Res> implements $ClipPlacementStateCopyWith<$Res> {
  factory _$ClipPlacementStateCopyWith(_ClipPlacementState value, $Res Function(_ClipPlacementState) _then) = __$ClipPlacementStateCopyWithImpl;
@override @useResult
$Res call({
 int? sourceId, UiSourceType? sourceType, int trackId, double timeSamples
});




}
/// @nodoc
class __$ClipPlacementStateCopyWithImpl<$Res>
    implements _$ClipPlacementStateCopyWith<$Res> {
  __$ClipPlacementStateCopyWithImpl(this._self, this._then);

  final _ClipPlacementState _self;
  final $Res Function(_ClipPlacementState) _then;

/// Create a copy of ClipPlacementState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = freezed,Object? sourceType = freezed,Object? trackId = null,Object? timeSamples = null,}) {
  return _then(_ClipPlacementState(
sourceId: freezed == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int?,sourceType: freezed == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as UiSourceType?,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,timeSamples: null == timeSamples ? _self.timeSamples : timeSamples // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
