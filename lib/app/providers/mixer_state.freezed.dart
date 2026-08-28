// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mixer_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MixerEditorState {

 mixer_api.UiMixerState? get mixerState; ISet<(int, String)> get touchedParams; IMap<int, double> get trackMagnitudes; IMap<int, double> get busMagnitudes; double get masterMagnitude;
/// Create a copy of MixerEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MixerEditorStateCopyWith<MixerEditorState> get copyWith => _$MixerEditorStateCopyWithImpl<MixerEditorState>(this as MixerEditorState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerEditorState&&(identical(other.mixerState, mixerState) || other.mixerState == mixerState)&&const DeepCollectionEquality().equals(other.touchedParams, touchedParams)&&(identical(other.trackMagnitudes, trackMagnitudes) || other.trackMagnitudes == trackMagnitudes)&&(identical(other.busMagnitudes, busMagnitudes) || other.busMagnitudes == busMagnitudes)&&(identical(other.masterMagnitude, masterMagnitude) || other.masterMagnitude == masterMagnitude));
}


@override
int get hashCode => Object.hash(runtimeType,mixerState,const DeepCollectionEquality().hash(touchedParams),trackMagnitudes,busMagnitudes,masterMagnitude);

@override
String toString() {
  return 'MixerEditorState(mixerState: $mixerState, touchedParams: $touchedParams, trackMagnitudes: $trackMagnitudes, busMagnitudes: $busMagnitudes, masterMagnitude: $masterMagnitude)';
}


}

/// @nodoc
abstract mixin class $MixerEditorStateCopyWith<$Res>  {
  factory $MixerEditorStateCopyWith(MixerEditorState value, $Res Function(MixerEditorState) _then) = _$MixerEditorStateCopyWithImpl;
@useResult
$Res call({
 mixer_api.UiMixerState? mixerState, ISet<(int, String)> touchedParams, IMap<int, double> trackMagnitudes, IMap<int, double> busMagnitudes, double masterMagnitude
});


$UiMixerStateCopyWith<$Res>? get mixerState;

}
/// @nodoc
class _$MixerEditorStateCopyWithImpl<$Res>
    implements $MixerEditorStateCopyWith<$Res> {
  _$MixerEditorStateCopyWithImpl(this._self, this._then);

  final MixerEditorState _self;
  final $Res Function(MixerEditorState) _then;

/// Create a copy of MixerEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mixerState = freezed,Object? touchedParams = null,Object? trackMagnitudes = null,Object? busMagnitudes = null,Object? masterMagnitude = null,}) {
  return _then(_self.copyWith(
mixerState: freezed == mixerState ? _self.mixerState : mixerState // ignore: cast_nullable_to_non_nullable
as mixer_api.UiMixerState?,touchedParams: null == touchedParams ? _self.touchedParams : touchedParams // ignore: cast_nullable_to_non_nullable
as ISet<(int, String)>,trackMagnitudes: null == trackMagnitudes ? _self.trackMagnitudes : trackMagnitudes // ignore: cast_nullable_to_non_nullable
as IMap<int, double>,busMagnitudes: null == busMagnitudes ? _self.busMagnitudes : busMagnitudes // ignore: cast_nullable_to_non_nullable
as IMap<int, double>,masterMagnitude: null == masterMagnitude ? _self.masterMagnitude : masterMagnitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of MixerEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiMixerStateCopyWith<$Res>? get mixerState {
    if (_self.mixerState == null) {
    return null;
  }

  return $UiMixerStateCopyWith<$Res>(_self.mixerState!, (value) {
    return _then(_self.copyWith(mixerState: value));
  });
}
}


/// Adds pattern-matching-related methods to [MixerEditorState].
extension MixerEditorStatePatterns on MixerEditorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MixerEditorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MixerEditorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MixerEditorState value)  $default,){
final _that = this;
switch (_that) {
case _MixerEditorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MixerEditorState value)?  $default,){
final _that = this;
switch (_that) {
case _MixerEditorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( mixer_api.UiMixerState? mixerState,  ISet<(int, String)> touchedParams,  IMap<int, double> trackMagnitudes,  IMap<int, double> busMagnitudes,  double masterMagnitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MixerEditorState() when $default != null:
return $default(_that.mixerState,_that.touchedParams,_that.trackMagnitudes,_that.busMagnitudes,_that.masterMagnitude);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( mixer_api.UiMixerState? mixerState,  ISet<(int, String)> touchedParams,  IMap<int, double> trackMagnitudes,  IMap<int, double> busMagnitudes,  double masterMagnitude)  $default,) {final _that = this;
switch (_that) {
case _MixerEditorState():
return $default(_that.mixerState,_that.touchedParams,_that.trackMagnitudes,_that.busMagnitudes,_that.masterMagnitude);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( mixer_api.UiMixerState? mixerState,  ISet<(int, String)> touchedParams,  IMap<int, double> trackMagnitudes,  IMap<int, double> busMagnitudes,  double masterMagnitude)?  $default,) {final _that = this;
switch (_that) {
case _MixerEditorState() when $default != null:
return $default(_that.mixerState,_that.touchedParams,_that.trackMagnitudes,_that.busMagnitudes,_that.masterMagnitude);case _:
  return null;

}
}

}

/// @nodoc


class _MixerEditorState implements MixerEditorState {
  const _MixerEditorState({this.mixerState, this.touchedParams = const ISetConst(<(int, String)>{}), this.trackMagnitudes = const IMapConst<int, double>({}), this.busMagnitudes = const IMapConst<int, double>({}), this.masterMagnitude = 0.0});
  

@override final  mixer_api.UiMixerState? mixerState;
@override@JsonKey() final  ISet<(int, String)> touchedParams;
@override@JsonKey() final  IMap<int, double> trackMagnitudes;
@override@JsonKey() final  IMap<int, double> busMagnitudes;
@override@JsonKey() final  double masterMagnitude;

/// Create a copy of MixerEditorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MixerEditorStateCopyWith<_MixerEditorState> get copyWith => __$MixerEditorStateCopyWithImpl<_MixerEditorState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MixerEditorState&&(identical(other.mixerState, mixerState) || other.mixerState == mixerState)&&const DeepCollectionEquality().equals(other.touchedParams, touchedParams)&&(identical(other.trackMagnitudes, trackMagnitudes) || other.trackMagnitudes == trackMagnitudes)&&(identical(other.busMagnitudes, busMagnitudes) || other.busMagnitudes == busMagnitudes)&&(identical(other.masterMagnitude, masterMagnitude) || other.masterMagnitude == masterMagnitude));
}


@override
int get hashCode => Object.hash(runtimeType,mixerState,const DeepCollectionEquality().hash(touchedParams),trackMagnitudes,busMagnitudes,masterMagnitude);

@override
String toString() {
  return 'MixerEditorState(mixerState: $mixerState, touchedParams: $touchedParams, trackMagnitudes: $trackMagnitudes, busMagnitudes: $busMagnitudes, masterMagnitude: $masterMagnitude)';
}


}

/// @nodoc
abstract mixin class _$MixerEditorStateCopyWith<$Res> implements $MixerEditorStateCopyWith<$Res> {
  factory _$MixerEditorStateCopyWith(_MixerEditorState value, $Res Function(_MixerEditorState) _then) = __$MixerEditorStateCopyWithImpl;
@override @useResult
$Res call({
 mixer_api.UiMixerState? mixerState, ISet<(int, String)> touchedParams, IMap<int, double> trackMagnitudes, IMap<int, double> busMagnitudes, double masterMagnitude
});


@override $UiMixerStateCopyWith<$Res>? get mixerState;

}
/// @nodoc
class __$MixerEditorStateCopyWithImpl<$Res>
    implements _$MixerEditorStateCopyWith<$Res> {
  __$MixerEditorStateCopyWithImpl(this._self, this._then);

  final _MixerEditorState _self;
  final $Res Function(_MixerEditorState) _then;

/// Create a copy of MixerEditorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mixerState = freezed,Object? touchedParams = null,Object? trackMagnitudes = null,Object? busMagnitudes = null,Object? masterMagnitude = null,}) {
  return _then(_MixerEditorState(
mixerState: freezed == mixerState ? _self.mixerState : mixerState // ignore: cast_nullable_to_non_nullable
as mixer_api.UiMixerState?,touchedParams: null == touchedParams ? _self.touchedParams : touchedParams // ignore: cast_nullable_to_non_nullable
as ISet<(int, String)>,trackMagnitudes: null == trackMagnitudes ? _self.trackMagnitudes : trackMagnitudes // ignore: cast_nullable_to_non_nullable
as IMap<int, double>,busMagnitudes: null == busMagnitudes ? _self.busMagnitudes : busMagnitudes // ignore: cast_nullable_to_non_nullable
as IMap<int, double>,masterMagnitude: null == masterMagnitude ? _self.masterMagnitude : masterMagnitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of MixerEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiMixerStateCopyWith<$Res>? get mixerState {
    if (_self.mixerState == null) {
    return null;
  }

  return $UiMixerStateCopyWith<$Res>(_self.mixerState!, (value) {
    return _then(_self.copyWith(mixerState: value));
  });
}
}

// dart format on
