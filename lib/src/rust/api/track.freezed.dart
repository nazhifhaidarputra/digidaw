// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiMadeUnique {

 List<UiClip> get clips; Map<int, UiPattern> get patterns; Map<int, UiGainEnvelope> get sourceEnvelopes;
/// Create a copy of UiMadeUnique
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMadeUniqueCopyWith<UiMadeUnique> get copyWith => _$UiMadeUniqueCopyWithImpl<UiMadeUnique>(this as UiMadeUnique, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMadeUnique&&const DeepCollectionEquality().equals(other.clips, clips)&&const DeepCollectionEquality().equals(other.patterns, patterns)&&const DeepCollectionEquality().equals(other.sourceEnvelopes, sourceEnvelopes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(clips),const DeepCollectionEquality().hash(patterns),const DeepCollectionEquality().hash(sourceEnvelopes));

@override
String toString() {
  return 'UiMadeUnique(clips: $clips, patterns: $patterns, sourceEnvelopes: $sourceEnvelopes)';
}


}

/// @nodoc
abstract mixin class $UiMadeUniqueCopyWith<$Res>  {
  factory $UiMadeUniqueCopyWith(UiMadeUnique value, $Res Function(UiMadeUnique) _then) = _$UiMadeUniqueCopyWithImpl;
@useResult
$Res call({
 List<UiClip> clips, Map<int, UiPattern> patterns, Map<int, UiGainEnvelope> sourceEnvelopes
});




}
/// @nodoc
class _$UiMadeUniqueCopyWithImpl<$Res>
    implements $UiMadeUniqueCopyWith<$Res> {
  _$UiMadeUniqueCopyWithImpl(this._self, this._then);

  final UiMadeUnique _self;
  final $Res Function(UiMadeUnique) _then;

/// Create a copy of UiMadeUnique
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clips = null,Object? patterns = null,Object? sourceEnvelopes = null,}) {
  return _then(_self.copyWith(
clips: null == clips ? _self.clips : clips // ignore: cast_nullable_to_non_nullable
as List<UiClip>,patterns: null == patterns ? _self.patterns : patterns // ignore: cast_nullable_to_non_nullable
as Map<int, UiPattern>,sourceEnvelopes: null == sourceEnvelopes ? _self.sourceEnvelopes : sourceEnvelopes // ignore: cast_nullable_to_non_nullable
as Map<int, UiGainEnvelope>,
  ));
}

}


/// Adds pattern-matching-related methods to [UiMadeUnique].
extension UiMadeUniquePatterns on UiMadeUnique {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiMadeUnique value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiMadeUnique() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiMadeUnique value)  $default,){
final _that = this;
switch (_that) {
case _UiMadeUnique():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiMadeUnique value)?  $default,){
final _that = this;
switch (_that) {
case _UiMadeUnique() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UiClip> clips,  Map<int, UiPattern> patterns,  Map<int, UiGainEnvelope> sourceEnvelopes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiMadeUnique() when $default != null:
return $default(_that.clips,_that.patterns,_that.sourceEnvelopes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UiClip> clips,  Map<int, UiPattern> patterns,  Map<int, UiGainEnvelope> sourceEnvelopes)  $default,) {final _that = this;
switch (_that) {
case _UiMadeUnique():
return $default(_that.clips,_that.patterns,_that.sourceEnvelopes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UiClip> clips,  Map<int, UiPattern> patterns,  Map<int, UiGainEnvelope> sourceEnvelopes)?  $default,) {final _that = this;
switch (_that) {
case _UiMadeUnique() when $default != null:
return $default(_that.clips,_that.patterns,_that.sourceEnvelopes);case _:
  return null;

}
}

}

/// @nodoc


class _UiMadeUnique implements UiMadeUnique {
  const _UiMadeUnique({required final  List<UiClip> clips, required final  Map<int, UiPattern> patterns, required final  Map<int, UiGainEnvelope> sourceEnvelopes}): _clips = clips,_patterns = patterns,_sourceEnvelopes = sourceEnvelopes;
  

 final  List<UiClip> _clips;
@override List<UiClip> get clips {
  if (_clips is EqualUnmodifiableListView) return _clips;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clips);
}

 final  Map<int, UiPattern> _patterns;
@override Map<int, UiPattern> get patterns {
  if (_patterns is EqualUnmodifiableMapView) return _patterns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_patterns);
}

 final  Map<int, UiGainEnvelope> _sourceEnvelopes;
@override Map<int, UiGainEnvelope> get sourceEnvelopes {
  if (_sourceEnvelopes is EqualUnmodifiableMapView) return _sourceEnvelopes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_sourceEnvelopes);
}


/// Create a copy of UiMadeUnique
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiMadeUniqueCopyWith<_UiMadeUnique> get copyWith => __$UiMadeUniqueCopyWithImpl<_UiMadeUnique>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiMadeUnique&&const DeepCollectionEquality().equals(other._clips, _clips)&&const DeepCollectionEquality().equals(other._patterns, _patterns)&&const DeepCollectionEquality().equals(other._sourceEnvelopes, _sourceEnvelopes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_clips),const DeepCollectionEquality().hash(_patterns),const DeepCollectionEquality().hash(_sourceEnvelopes));

@override
String toString() {
  return 'UiMadeUnique(clips: $clips, patterns: $patterns, sourceEnvelopes: $sourceEnvelopes)';
}


}

/// @nodoc
abstract mixin class _$UiMadeUniqueCopyWith<$Res> implements $UiMadeUniqueCopyWith<$Res> {
  factory _$UiMadeUniqueCopyWith(_UiMadeUnique value, $Res Function(_UiMadeUnique) _then) = __$UiMadeUniqueCopyWithImpl;
@override @useResult
$Res call({
 List<UiClip> clips, Map<int, UiPattern> patterns, Map<int, UiGainEnvelope> sourceEnvelopes
});




}
/// @nodoc
class __$UiMadeUniqueCopyWithImpl<$Res>
    implements _$UiMadeUniqueCopyWith<$Res> {
  __$UiMadeUniqueCopyWithImpl(this._self, this._then);

  final _UiMadeUnique _self;
  final $Res Function(_UiMadeUnique) _then;

/// Create a copy of UiMadeUnique
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clips = null,Object? patterns = null,Object? sourceEnvelopes = null,}) {
  return _then(_UiMadeUnique(
clips: null == clips ? _self._clips : clips // ignore: cast_nullable_to_non_nullable
as List<UiClip>,patterns: null == patterns ? _self._patterns : patterns // ignore: cast_nullable_to_non_nullable
as Map<int, UiPattern>,sourceEnvelopes: null == sourceEnvelopes ? _self._sourceEnvelopes : sourceEnvelopes // ignore: cast_nullable_to_non_nullable
as Map<int, UiGainEnvelope>,
  ));
}


}

// dart format on
