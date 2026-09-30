// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_analysis.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiBeatGrid {

 double get bpm; double get confidence; Float32List get beats; Float32List get downbeats;
/// Create a copy of UiBeatGrid
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiBeatGridCopyWith<UiBeatGrid> get copyWith => _$UiBeatGridCopyWithImpl<UiBeatGrid>(this as UiBeatGrid, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiBeatGrid&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&const DeepCollectionEquality().equals(other.beats, beats)&&const DeepCollectionEquality().equals(other.downbeats, downbeats));
}


@override
int get hashCode => Object.hash(runtimeType,bpm,confidence,const DeepCollectionEquality().hash(beats),const DeepCollectionEquality().hash(downbeats));

@override
String toString() {
  return 'UiBeatGrid(bpm: $bpm, confidence: $confidence, beats: $beats, downbeats: $downbeats)';
}


}

/// @nodoc
abstract mixin class $UiBeatGridCopyWith<$Res>  {
  factory $UiBeatGridCopyWith(UiBeatGrid value, $Res Function(UiBeatGrid) _then) = _$UiBeatGridCopyWithImpl;
@useResult
$Res call({
 double bpm, double confidence, Float32List beats, Float32List downbeats
});




}
/// @nodoc
class _$UiBeatGridCopyWithImpl<$Res>
    implements $UiBeatGridCopyWith<$Res> {
  _$UiBeatGridCopyWithImpl(this._self, this._then);

  final UiBeatGrid _self;
  final $Res Function(UiBeatGrid) _then;

/// Create a copy of UiBeatGrid
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bpm = null,Object? confidence = null,Object? beats = null,Object? downbeats = null,}) {
  return _then(_self.copyWith(
bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,beats: null == beats ? _self.beats : beats // ignore: cast_nullable_to_non_nullable
as Float32List,downbeats: null == downbeats ? _self.downbeats : downbeats // ignore: cast_nullable_to_non_nullable
as Float32List,
  ));
}

}


/// Adds pattern-matching-related methods to [UiBeatGrid].
extension UiBeatGridPatterns on UiBeatGrid {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiBeatGrid value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiBeatGrid() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiBeatGrid value)  $default,){
final _that = this;
switch (_that) {
case _UiBeatGrid():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiBeatGrid value)?  $default,){
final _that = this;
switch (_that) {
case _UiBeatGrid() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double bpm,  double confidence,  Float32List beats,  Float32List downbeats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiBeatGrid() when $default != null:
return $default(_that.bpm,_that.confidence,_that.beats,_that.downbeats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double bpm,  double confidence,  Float32List beats,  Float32List downbeats)  $default,) {final _that = this;
switch (_that) {
case _UiBeatGrid():
return $default(_that.bpm,_that.confidence,_that.beats,_that.downbeats);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double bpm,  double confidence,  Float32List beats,  Float32List downbeats)?  $default,) {final _that = this;
switch (_that) {
case _UiBeatGrid() when $default != null:
return $default(_that.bpm,_that.confidence,_that.beats,_that.downbeats);case _:
  return null;

}
}

}

/// @nodoc


class _UiBeatGrid implements UiBeatGrid {
  const _UiBeatGrid({required this.bpm, required this.confidence, required this.beats, required this.downbeats});
  

@override final  double bpm;
@override final  double confidence;
@override final  Float32List beats;
@override final  Float32List downbeats;

/// Create a copy of UiBeatGrid
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiBeatGridCopyWith<_UiBeatGrid> get copyWith => __$UiBeatGridCopyWithImpl<_UiBeatGrid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiBeatGrid&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&const DeepCollectionEquality().equals(other.beats, beats)&&const DeepCollectionEquality().equals(other.downbeats, downbeats));
}


@override
int get hashCode => Object.hash(runtimeType,bpm,confidence,const DeepCollectionEquality().hash(beats),const DeepCollectionEquality().hash(downbeats));

@override
String toString() {
  return 'UiBeatGrid(bpm: $bpm, confidence: $confidence, beats: $beats, downbeats: $downbeats)';
}


}

/// @nodoc
abstract mixin class _$UiBeatGridCopyWith<$Res> implements $UiBeatGridCopyWith<$Res> {
  factory _$UiBeatGridCopyWith(_UiBeatGrid value, $Res Function(_UiBeatGrid) _then) = __$UiBeatGridCopyWithImpl;
@override @useResult
$Res call({
 double bpm, double confidence, Float32List beats, Float32List downbeats
});




}
/// @nodoc
class __$UiBeatGridCopyWithImpl<$Res>
    implements _$UiBeatGridCopyWith<$Res> {
  __$UiBeatGridCopyWithImpl(this._self, this._then);

  final _UiBeatGrid _self;
  final $Res Function(_UiBeatGrid) _then;

/// Create a copy of UiBeatGrid
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bpm = null,Object? confidence = null,Object? beats = null,Object? downbeats = null,}) {
  return _then(_UiBeatGrid(
bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,beats: null == beats ? _self.beats : beats // ignore: cast_nullable_to_non_nullable
as Float32List,downbeats: null == downbeats ? _self.downbeats : downbeats // ignore: cast_nullable_to_non_nullable
as Float32List,
  ));
}


}

// dart format on
