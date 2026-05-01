// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transport.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaybackModeDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackModeDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PlaybackModeDto()';
}


}

/// @nodoc
class $PlaybackModeDtoCopyWith<$Res>  {
$PlaybackModeDtoCopyWith(PlaybackModeDto _, $Res Function(PlaybackModeDto) __);
}


/// Adds pattern-matching-related methods to [PlaybackModeDto].
extension PlaybackModeDtoPatterns on PlaybackModeDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PlaybackModeDto_Song value)?  song,TResult Function( PlaybackModeDto_Pattern value)?  pattern,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PlaybackModeDto_Song() when song != null:
return song(_that);case PlaybackModeDto_Pattern() when pattern != null:
return pattern(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PlaybackModeDto_Song value)  song,required TResult Function( PlaybackModeDto_Pattern value)  pattern,}){
final _that = this;
switch (_that) {
case PlaybackModeDto_Song():
return song(_that);case PlaybackModeDto_Pattern():
return pattern(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PlaybackModeDto_Song value)?  song,TResult? Function( PlaybackModeDto_Pattern value)?  pattern,}){
final _that = this;
switch (_that) {
case PlaybackModeDto_Song() when song != null:
return song(_that);case PlaybackModeDto_Pattern() when pattern != null:
return pattern(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  song,TResult Function( int patternId,  int generatorId)?  pattern,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PlaybackModeDto_Song() when song != null:
return song();case PlaybackModeDto_Pattern() when pattern != null:
return pattern(_that.patternId,_that.generatorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  song,required TResult Function( int patternId,  int generatorId)  pattern,}) {final _that = this;
switch (_that) {
case PlaybackModeDto_Song():
return song();case PlaybackModeDto_Pattern():
return pattern(_that.patternId,_that.generatorId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  song,TResult? Function( int patternId,  int generatorId)?  pattern,}) {final _that = this;
switch (_that) {
case PlaybackModeDto_Song() when song != null:
return song();case PlaybackModeDto_Pattern() when pattern != null:
return pattern(_that.patternId,_that.generatorId);case _:
  return null;

}
}

}

/// @nodoc


class PlaybackModeDto_Song extends PlaybackModeDto {
  const PlaybackModeDto_Song(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackModeDto_Song);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PlaybackModeDto.song()';
}


}




/// @nodoc


class PlaybackModeDto_Pattern extends PlaybackModeDto {
  const PlaybackModeDto_Pattern({required this.patternId, required this.generatorId}): super._();
  

 final  int patternId;
 final  int generatorId;

/// Create a copy of PlaybackModeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackModeDto_PatternCopyWith<PlaybackModeDto_Pattern> get copyWith => _$PlaybackModeDto_PatternCopyWithImpl<PlaybackModeDto_Pattern>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackModeDto_Pattern&&(identical(other.patternId, patternId) || other.patternId == patternId)&&(identical(other.generatorId, generatorId) || other.generatorId == generatorId));
}


@override
int get hashCode => Object.hash(runtimeType,patternId,generatorId);

@override
String toString() {
  return 'PlaybackModeDto.pattern(patternId: $patternId, generatorId: $generatorId)';
}


}

/// @nodoc
abstract mixin class $PlaybackModeDto_PatternCopyWith<$Res> implements $PlaybackModeDtoCopyWith<$Res> {
  factory $PlaybackModeDto_PatternCopyWith(PlaybackModeDto_Pattern value, $Res Function(PlaybackModeDto_Pattern) _then) = _$PlaybackModeDto_PatternCopyWithImpl;
@useResult
$Res call({
 int patternId, int generatorId
});




}
/// @nodoc
class _$PlaybackModeDto_PatternCopyWithImpl<$Res>
    implements $PlaybackModeDto_PatternCopyWith<$Res> {
  _$PlaybackModeDto_PatternCopyWithImpl(this._self, this._then);

  final PlaybackModeDto_Pattern _self;
  final $Res Function(PlaybackModeDto_Pattern) _then;

/// Create a copy of PlaybackModeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? patternId = null,Object? generatorId = null,}) {
  return _then(PlaybackModeDto_Pattern(
patternId: null == patternId ? _self.patternId : patternId // ignore: cast_nullable_to_non_nullable
as int,generatorId: null == generatorId ? _self.generatorId : generatorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
