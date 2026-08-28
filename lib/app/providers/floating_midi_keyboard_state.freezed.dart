// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'floating_midi_keyboard_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FloatingMidiKeyboardState {

/// Whether the keyboard panel is currently visible.
 bool get showed;/// MIDI note number of the lowest visible key.
/// Clamped to [21, 120] by [FloatingMidiKeyboardNotifier.setBaseKey].
 int get baseKey;/// Number of keys shown on the keyboard.
/// Clamped to [12, 24] by [FloatingMidiKeyboardNotifier.setKeyRange].
 int get keyRange;/// The generator whose sound is triggered by key presses.
/// `null` means no generator is selected yet.
 int? get selectedGeneratorId;
/// Create a copy of FloatingMidiKeyboardState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FloatingMidiKeyboardStateCopyWith<FloatingMidiKeyboardState> get copyWith => _$FloatingMidiKeyboardStateCopyWithImpl<FloatingMidiKeyboardState>(this as FloatingMidiKeyboardState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FloatingMidiKeyboardState&&(identical(other.showed, showed) || other.showed == showed)&&(identical(other.baseKey, baseKey) || other.baseKey == baseKey)&&(identical(other.keyRange, keyRange) || other.keyRange == keyRange)&&(identical(other.selectedGeneratorId, selectedGeneratorId) || other.selectedGeneratorId == selectedGeneratorId));
}


@override
int get hashCode => Object.hash(runtimeType,showed,baseKey,keyRange,selectedGeneratorId);

@override
String toString() {
  return 'FloatingMidiKeyboardState(showed: $showed, baseKey: $baseKey, keyRange: $keyRange, selectedGeneratorId: $selectedGeneratorId)';
}


}

/// @nodoc
abstract mixin class $FloatingMidiKeyboardStateCopyWith<$Res>  {
  factory $FloatingMidiKeyboardStateCopyWith(FloatingMidiKeyboardState value, $Res Function(FloatingMidiKeyboardState) _then) = _$FloatingMidiKeyboardStateCopyWithImpl;
@useResult
$Res call({
 bool showed, int baseKey, int keyRange, int? selectedGeneratorId
});




}
/// @nodoc
class _$FloatingMidiKeyboardStateCopyWithImpl<$Res>
    implements $FloatingMidiKeyboardStateCopyWith<$Res> {
  _$FloatingMidiKeyboardStateCopyWithImpl(this._self, this._then);

  final FloatingMidiKeyboardState _self;
  final $Res Function(FloatingMidiKeyboardState) _then;

/// Create a copy of FloatingMidiKeyboardState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? showed = null,Object? baseKey = null,Object? keyRange = null,Object? selectedGeneratorId = freezed,}) {
  return _then(_self.copyWith(
showed: null == showed ? _self.showed : showed // ignore: cast_nullable_to_non_nullable
as bool,baseKey: null == baseKey ? _self.baseKey : baseKey // ignore: cast_nullable_to_non_nullable
as int,keyRange: null == keyRange ? _self.keyRange : keyRange // ignore: cast_nullable_to_non_nullable
as int,selectedGeneratorId: freezed == selectedGeneratorId ? _self.selectedGeneratorId : selectedGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [FloatingMidiKeyboardState].
extension FloatingMidiKeyboardStatePatterns on FloatingMidiKeyboardState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FloatingMidiKeyboardState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FloatingMidiKeyboardState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FloatingMidiKeyboardState value)  $default,){
final _that = this;
switch (_that) {
case _FloatingMidiKeyboardState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FloatingMidiKeyboardState value)?  $default,){
final _that = this;
switch (_that) {
case _FloatingMidiKeyboardState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool showed,  int baseKey,  int keyRange,  int? selectedGeneratorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FloatingMidiKeyboardState() when $default != null:
return $default(_that.showed,_that.baseKey,_that.keyRange,_that.selectedGeneratorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool showed,  int baseKey,  int keyRange,  int? selectedGeneratorId)  $default,) {final _that = this;
switch (_that) {
case _FloatingMidiKeyboardState():
return $default(_that.showed,_that.baseKey,_that.keyRange,_that.selectedGeneratorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool showed,  int baseKey,  int keyRange,  int? selectedGeneratorId)?  $default,) {final _that = this;
switch (_that) {
case _FloatingMidiKeyboardState() when $default != null:
return $default(_that.showed,_that.baseKey,_that.keyRange,_that.selectedGeneratorId);case _:
  return null;

}
}

}

/// @nodoc


class _FloatingMidiKeyboardState implements FloatingMidiKeyboardState {
  const _FloatingMidiKeyboardState({this.showed = false, this.baseKey = 48, this.keyRange = 15, this.selectedGeneratorId});
  

/// Whether the keyboard panel is currently visible.
@override@JsonKey() final  bool showed;
/// MIDI note number of the lowest visible key.
/// Clamped to [21, 120] by [FloatingMidiKeyboardNotifier.setBaseKey].
@override@JsonKey() final  int baseKey;
/// Number of keys shown on the keyboard.
/// Clamped to [12, 24] by [FloatingMidiKeyboardNotifier.setKeyRange].
@override@JsonKey() final  int keyRange;
/// The generator whose sound is triggered by key presses.
/// `null` means no generator is selected yet.
@override final  int? selectedGeneratorId;

/// Create a copy of FloatingMidiKeyboardState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FloatingMidiKeyboardStateCopyWith<_FloatingMidiKeyboardState> get copyWith => __$FloatingMidiKeyboardStateCopyWithImpl<_FloatingMidiKeyboardState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FloatingMidiKeyboardState&&(identical(other.showed, showed) || other.showed == showed)&&(identical(other.baseKey, baseKey) || other.baseKey == baseKey)&&(identical(other.keyRange, keyRange) || other.keyRange == keyRange)&&(identical(other.selectedGeneratorId, selectedGeneratorId) || other.selectedGeneratorId == selectedGeneratorId));
}


@override
int get hashCode => Object.hash(runtimeType,showed,baseKey,keyRange,selectedGeneratorId);

@override
String toString() {
  return 'FloatingMidiKeyboardState(showed: $showed, baseKey: $baseKey, keyRange: $keyRange, selectedGeneratorId: $selectedGeneratorId)';
}


}

/// @nodoc
abstract mixin class _$FloatingMidiKeyboardStateCopyWith<$Res> implements $FloatingMidiKeyboardStateCopyWith<$Res> {
  factory _$FloatingMidiKeyboardStateCopyWith(_FloatingMidiKeyboardState value, $Res Function(_FloatingMidiKeyboardState) _then) = __$FloatingMidiKeyboardStateCopyWithImpl;
@override @useResult
$Res call({
 bool showed, int baseKey, int keyRange, int? selectedGeneratorId
});




}
/// @nodoc
class __$FloatingMidiKeyboardStateCopyWithImpl<$Res>
    implements _$FloatingMidiKeyboardStateCopyWith<$Res> {
  __$FloatingMidiKeyboardStateCopyWithImpl(this._self, this._then);

  final _FloatingMidiKeyboardState _self;
  final $Res Function(_FloatingMidiKeyboardState) _then;

/// Create a copy of FloatingMidiKeyboardState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? showed = null,Object? baseKey = null,Object? keyRange = null,Object? selectedGeneratorId = freezed,}) {
  return _then(_FloatingMidiKeyboardState(
showed: null == showed ? _self.showed : showed // ignore: cast_nullable_to_non_nullable
as bool,baseKey: null == baseKey ? _self.baseKey : baseKey // ignore: cast_nullable_to_non_nullable
as int,keyRange: null == keyRange ? _self.keyRange : keyRange // ignore: cast_nullable_to_non_nullable
as int,selectedGeneratorId: freezed == selectedGeneratorId ? _self.selectedGeneratorId : selectedGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
