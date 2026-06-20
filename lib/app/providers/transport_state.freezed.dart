// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transport_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransportStateData {

 UiTransportState? get state; bool get isLooping; bool get isPatternPlaying; bool get isPatternMode; bool get isMetronomeActive;
/// Create a copy of TransportStateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransportStateDataCopyWith<TransportStateData> get copyWith => _$TransportStateDataCopyWithImpl<TransportStateData>(this as TransportStateData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportStateData&&(identical(other.state, state) || other.state == state)&&(identical(other.isLooping, isLooping) || other.isLooping == isLooping)&&(identical(other.isPatternPlaying, isPatternPlaying) || other.isPatternPlaying == isPatternPlaying)&&(identical(other.isPatternMode, isPatternMode) || other.isPatternMode == isPatternMode)&&(identical(other.isMetronomeActive, isMetronomeActive) || other.isMetronomeActive == isMetronomeActive));
}


@override
int get hashCode => Object.hash(runtimeType,state,isLooping,isPatternPlaying,isPatternMode,isMetronomeActive);

@override
String toString() {
  return 'TransportStateData(state: $state, isLooping: $isLooping, isPatternPlaying: $isPatternPlaying, isPatternMode: $isPatternMode, isMetronomeActive: $isMetronomeActive)';
}


}

/// @nodoc
abstract mixin class $TransportStateDataCopyWith<$Res>  {
  factory $TransportStateDataCopyWith(TransportStateData value, $Res Function(TransportStateData) _then) = _$TransportStateDataCopyWithImpl;
@useResult
$Res call({
 UiTransportState? state, bool isLooping, bool isPatternPlaying, bool isPatternMode, bool isMetronomeActive
});


$UiTransportStateCopyWith<$Res>? get state;

}
/// @nodoc
class _$TransportStateDataCopyWithImpl<$Res>
    implements $TransportStateDataCopyWith<$Res> {
  _$TransportStateDataCopyWithImpl(this._self, this._then);

  final TransportStateData _self;
  final $Res Function(TransportStateData) _then;

/// Create a copy of TransportStateData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = freezed,Object? isLooping = null,Object? isPatternPlaying = null,Object? isPatternMode = null,Object? isMetronomeActive = null,}) {
  return _then(_self.copyWith(
state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as UiTransportState?,isLooping: null == isLooping ? _self.isLooping : isLooping // ignore: cast_nullable_to_non_nullable
as bool,isPatternPlaying: null == isPatternPlaying ? _self.isPatternPlaying : isPatternPlaying // ignore: cast_nullable_to_non_nullable
as bool,isPatternMode: null == isPatternMode ? _self.isPatternMode : isPatternMode // ignore: cast_nullable_to_non_nullable
as bool,isMetronomeActive: null == isMetronomeActive ? _self.isMetronomeActive : isMetronomeActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of TransportStateData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiTransportStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $UiTransportStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}


/// Adds pattern-matching-related methods to [TransportStateData].
extension TransportStateDataPatterns on TransportStateData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransportStateData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransportStateData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransportStateData value)  $default,){
final _that = this;
switch (_that) {
case _TransportStateData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransportStateData value)?  $default,){
final _that = this;
switch (_that) {
case _TransportStateData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiTransportState? state,  bool isLooping,  bool isPatternPlaying,  bool isPatternMode,  bool isMetronomeActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransportStateData() when $default != null:
return $default(_that.state,_that.isLooping,_that.isPatternPlaying,_that.isPatternMode,_that.isMetronomeActive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiTransportState? state,  bool isLooping,  bool isPatternPlaying,  bool isPatternMode,  bool isMetronomeActive)  $default,) {final _that = this;
switch (_that) {
case _TransportStateData():
return $default(_that.state,_that.isLooping,_that.isPatternPlaying,_that.isPatternMode,_that.isMetronomeActive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiTransportState? state,  bool isLooping,  bool isPatternPlaying,  bool isPatternMode,  bool isMetronomeActive)?  $default,) {final _that = this;
switch (_that) {
case _TransportStateData() when $default != null:
return $default(_that.state,_that.isLooping,_that.isPatternPlaying,_that.isPatternMode,_that.isMetronomeActive);case _:
  return null;

}
}

}

/// @nodoc


class _TransportStateData implements TransportStateData {
  const _TransportStateData({this.state, this.isLooping = false, this.isPatternPlaying = false, this.isPatternMode = false, this.isMetronomeActive = false});
  

@override final  UiTransportState? state;
@override@JsonKey() final  bool isLooping;
@override@JsonKey() final  bool isPatternPlaying;
@override@JsonKey() final  bool isPatternMode;
@override@JsonKey() final  bool isMetronomeActive;

/// Create a copy of TransportStateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransportStateDataCopyWith<_TransportStateData> get copyWith => __$TransportStateDataCopyWithImpl<_TransportStateData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransportStateData&&(identical(other.state, state) || other.state == state)&&(identical(other.isLooping, isLooping) || other.isLooping == isLooping)&&(identical(other.isPatternPlaying, isPatternPlaying) || other.isPatternPlaying == isPatternPlaying)&&(identical(other.isPatternMode, isPatternMode) || other.isPatternMode == isPatternMode)&&(identical(other.isMetronomeActive, isMetronomeActive) || other.isMetronomeActive == isMetronomeActive));
}


@override
int get hashCode => Object.hash(runtimeType,state,isLooping,isPatternPlaying,isPatternMode,isMetronomeActive);

@override
String toString() {
  return 'TransportStateData(state: $state, isLooping: $isLooping, isPatternPlaying: $isPatternPlaying, isPatternMode: $isPatternMode, isMetronomeActive: $isMetronomeActive)';
}


}

/// @nodoc
abstract mixin class _$TransportStateDataCopyWith<$Res> implements $TransportStateDataCopyWith<$Res> {
  factory _$TransportStateDataCopyWith(_TransportStateData value, $Res Function(_TransportStateData) _then) = __$TransportStateDataCopyWithImpl;
@override @useResult
$Res call({
 UiTransportState? state, bool isLooping, bool isPatternPlaying, bool isPatternMode, bool isMetronomeActive
});


@override $UiTransportStateCopyWith<$Res>? get state;

}
/// @nodoc
class __$TransportStateDataCopyWithImpl<$Res>
    implements _$TransportStateDataCopyWith<$Res> {
  __$TransportStateDataCopyWithImpl(this._self, this._then);

  final _TransportStateData _self;
  final $Res Function(_TransportStateData) _then;

/// Create a copy of TransportStateData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = freezed,Object? isLooping = null,Object? isPatternPlaying = null,Object? isPatternMode = null,Object? isMetronomeActive = null,}) {
  return _then(_TransportStateData(
state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as UiTransportState?,isLooping: null == isLooping ? _self.isLooping : isLooping // ignore: cast_nullable_to_non_nullable
as bool,isPatternPlaying: null == isPatternPlaying ? _self.isPatternPlaying : isPatternPlaying // ignore: cast_nullable_to_non_nullable
as bool,isPatternMode: null == isPatternMode ? _self.isPatternMode : isPatternMode // ignore: cast_nullable_to_non_nullable
as bool,isMetronomeActive: null == isMetronomeActive ? _self.isMetronomeActive : isMetronomeActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of TransportStateData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiTransportStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $UiTransportStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

// dart format on
