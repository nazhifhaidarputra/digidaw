// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mixer_channel_sidepanel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MixerChannelPanelState {

 bool get isOpen;/// The track, bus or master whose strip and effect rack are shown.
 UiMixerChannelTarget? get target;
/// Create a copy of MixerChannelPanelState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MixerChannelPanelStateCopyWith<MixerChannelPanelState> get copyWith => _$MixerChannelPanelStateCopyWithImpl<MixerChannelPanelState>(this as MixerChannelPanelState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelPanelState&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,isOpen,target);

@override
String toString() {
  return 'MixerChannelPanelState(isOpen: $isOpen, target: $target)';
}


}

/// @nodoc
abstract mixin class $MixerChannelPanelStateCopyWith<$Res>  {
  factory $MixerChannelPanelStateCopyWith(MixerChannelPanelState value, $Res Function(MixerChannelPanelState) _then) = _$MixerChannelPanelStateCopyWithImpl;
@useResult
$Res call({
 bool isOpen, UiMixerChannelTarget? target
});


$UiMixerChannelTargetCopyWith<$Res>? get target;

}
/// @nodoc
class _$MixerChannelPanelStateCopyWithImpl<$Res>
    implements $MixerChannelPanelStateCopyWith<$Res> {
  _$MixerChannelPanelStateCopyWithImpl(this._self, this._then);

  final MixerChannelPanelState _self;
  final $Res Function(MixerChannelPanelState) _then;

/// Create a copy of MixerChannelPanelState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isOpen = null,Object? target = freezed,}) {
  return _then(_self.copyWith(
isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as UiMixerChannelTarget?,
  ));
}
/// Create a copy of MixerChannelPanelState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiMixerChannelTargetCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $UiMixerChannelTargetCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// Adds pattern-matching-related methods to [MixerChannelPanelState].
extension MixerChannelPanelStatePatterns on MixerChannelPanelState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MixerChannelPanelState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MixerChannelPanelState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MixerChannelPanelState value)  $default,){
final _that = this;
switch (_that) {
case _MixerChannelPanelState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MixerChannelPanelState value)?  $default,){
final _that = this;
switch (_that) {
case _MixerChannelPanelState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isOpen,  UiMixerChannelTarget? target)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MixerChannelPanelState() when $default != null:
return $default(_that.isOpen,_that.target);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isOpen,  UiMixerChannelTarget? target)  $default,) {final _that = this;
switch (_that) {
case _MixerChannelPanelState():
return $default(_that.isOpen,_that.target);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isOpen,  UiMixerChannelTarget? target)?  $default,) {final _that = this;
switch (_that) {
case _MixerChannelPanelState() when $default != null:
return $default(_that.isOpen,_that.target);case _:
  return null;

}
}

}

/// @nodoc


class _MixerChannelPanelState implements MixerChannelPanelState {
  const _MixerChannelPanelState({this.isOpen = false, this.target});
  

@override@JsonKey() final  bool isOpen;
/// The track, bus or master whose strip and effect rack are shown.
@override final  UiMixerChannelTarget? target;

/// Create a copy of MixerChannelPanelState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MixerChannelPanelStateCopyWith<_MixerChannelPanelState> get copyWith => __$MixerChannelPanelStateCopyWithImpl<_MixerChannelPanelState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MixerChannelPanelState&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,isOpen,target);

@override
String toString() {
  return 'MixerChannelPanelState(isOpen: $isOpen, target: $target)';
}


}

/// @nodoc
abstract mixin class _$MixerChannelPanelStateCopyWith<$Res> implements $MixerChannelPanelStateCopyWith<$Res> {
  factory _$MixerChannelPanelStateCopyWith(_MixerChannelPanelState value, $Res Function(_MixerChannelPanelState) _then) = __$MixerChannelPanelStateCopyWithImpl;
@override @useResult
$Res call({
 bool isOpen, UiMixerChannelTarget? target
});


@override $UiMixerChannelTargetCopyWith<$Res>? get target;

}
/// @nodoc
class __$MixerChannelPanelStateCopyWithImpl<$Res>
    implements _$MixerChannelPanelStateCopyWith<$Res> {
  __$MixerChannelPanelStateCopyWithImpl(this._self, this._then);

  final _MixerChannelPanelState _self;
  final $Res Function(_MixerChannelPanelState) _then;

/// Create a copy of MixerChannelPanelState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isOpen = null,Object? target = freezed,}) {
  return _then(_MixerChannelPanelState(
isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as UiMixerChannelTarget?,
  ));
}

/// Create a copy of MixerChannelPanelState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiMixerChannelTargetCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $UiMixerChannelTargetCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

// dart format on
