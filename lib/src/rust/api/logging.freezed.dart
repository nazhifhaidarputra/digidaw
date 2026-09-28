// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'logging.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RustLogEntryDto {

 int get timestampMillis; RustLogLevel get level; String get target; String get message;
/// Create a copy of RustLogEntryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RustLogEntryDtoCopyWith<RustLogEntryDto> get copyWith => _$RustLogEntryDtoCopyWithImpl<RustLogEntryDto>(this as RustLogEntryDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RustLogEntryDto&&(identical(other.timestampMillis, timestampMillis) || other.timestampMillis == timestampMillis)&&(identical(other.level, level) || other.level == level)&&(identical(other.target, target) || other.target == target)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,timestampMillis,level,target,message);

@override
String toString() {
  return 'RustLogEntryDto(timestampMillis: $timestampMillis, level: $level, target: $target, message: $message)';
}


}

/// @nodoc
abstract mixin class $RustLogEntryDtoCopyWith<$Res>  {
  factory $RustLogEntryDtoCopyWith(RustLogEntryDto value, $Res Function(RustLogEntryDto) _then) = _$RustLogEntryDtoCopyWithImpl;
@useResult
$Res call({
 int timestampMillis, RustLogLevel level, String target, String message
});




}
/// @nodoc
class _$RustLogEntryDtoCopyWithImpl<$Res>
    implements $RustLogEntryDtoCopyWith<$Res> {
  _$RustLogEntryDtoCopyWithImpl(this._self, this._then);

  final RustLogEntryDto _self;
  final $Res Function(RustLogEntryDto) _then;

/// Create a copy of RustLogEntryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestampMillis = null,Object? level = null,Object? target = null,Object? message = null,}) {
  return _then(_self.copyWith(
timestampMillis: null == timestampMillis ? _self.timestampMillis : timestampMillis // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as RustLogLevel,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RustLogEntryDto].
extension RustLogEntryDtoPatterns on RustLogEntryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RustLogEntryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RustLogEntryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RustLogEntryDto value)  $default,){
final _that = this;
switch (_that) {
case _RustLogEntryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RustLogEntryDto value)?  $default,){
final _that = this;
switch (_that) {
case _RustLogEntryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int timestampMillis,  RustLogLevel level,  String target,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RustLogEntryDto() when $default != null:
return $default(_that.timestampMillis,_that.level,_that.target,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int timestampMillis,  RustLogLevel level,  String target,  String message)  $default,) {final _that = this;
switch (_that) {
case _RustLogEntryDto():
return $default(_that.timestampMillis,_that.level,_that.target,_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int timestampMillis,  RustLogLevel level,  String target,  String message)?  $default,) {final _that = this;
switch (_that) {
case _RustLogEntryDto() when $default != null:
return $default(_that.timestampMillis,_that.level,_that.target,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _RustLogEntryDto implements RustLogEntryDto {
  const _RustLogEntryDto({required this.timestampMillis, required this.level, required this.target, required this.message});
  

@override final  int timestampMillis;
@override final  RustLogLevel level;
@override final  String target;
@override final  String message;

/// Create a copy of RustLogEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RustLogEntryDtoCopyWith<_RustLogEntryDto> get copyWith => __$RustLogEntryDtoCopyWithImpl<_RustLogEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RustLogEntryDto&&(identical(other.timestampMillis, timestampMillis) || other.timestampMillis == timestampMillis)&&(identical(other.level, level) || other.level == level)&&(identical(other.target, target) || other.target == target)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,timestampMillis,level,target,message);

@override
String toString() {
  return 'RustLogEntryDto(timestampMillis: $timestampMillis, level: $level, target: $target, message: $message)';
}


}

/// @nodoc
abstract mixin class _$RustLogEntryDtoCopyWith<$Res> implements $RustLogEntryDtoCopyWith<$Res> {
  factory _$RustLogEntryDtoCopyWith(_RustLogEntryDto value, $Res Function(_RustLogEntryDto) _then) = __$RustLogEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 int timestampMillis, RustLogLevel level, String target, String message
});




}
/// @nodoc
class __$RustLogEntryDtoCopyWithImpl<$Res>
    implements _$RustLogEntryDtoCopyWith<$Res> {
  __$RustLogEntryDtoCopyWithImpl(this._self, this._then);

  final _RustLogEntryDto _self;
  final $Res Function(_RustLogEntryDto) _then;

/// Create a copy of RustLogEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestampMillis = null,Object? level = null,Object? target = null,Object? message = null,}) {
  return _then(_RustLogEntryDto(
timestampMillis: null == timestampMillis ? _self.timestampMillis : timestampMillis // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as RustLogLevel,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
