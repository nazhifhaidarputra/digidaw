// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'general_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GeneralSettingsState {

 int get maxHistoryEntries; bool get isApplyingHistoryLimit; bool get isInitialized;
/// Create a copy of GeneralSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeneralSettingsStateCopyWith<GeneralSettingsState> get copyWith => _$GeneralSettingsStateCopyWithImpl<GeneralSettingsState>(this as GeneralSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeneralSettingsState&&(identical(other.maxHistoryEntries, maxHistoryEntries) || other.maxHistoryEntries == maxHistoryEntries)&&(identical(other.isApplyingHistoryLimit, isApplyingHistoryLimit) || other.isApplyingHistoryLimit == isApplyingHistoryLimit)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,maxHistoryEntries,isApplyingHistoryLimit,isInitialized);

@override
String toString() {
  return 'GeneralSettingsState(maxHistoryEntries: $maxHistoryEntries, isApplyingHistoryLimit: $isApplyingHistoryLimit, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class $GeneralSettingsStateCopyWith<$Res>  {
  factory $GeneralSettingsStateCopyWith(GeneralSettingsState value, $Res Function(GeneralSettingsState) _then) = _$GeneralSettingsStateCopyWithImpl;
@useResult
$Res call({
 int maxHistoryEntries, bool isApplyingHistoryLimit, bool isInitialized
});




}
/// @nodoc
class _$GeneralSettingsStateCopyWithImpl<$Res>
    implements $GeneralSettingsStateCopyWith<$Res> {
  _$GeneralSettingsStateCopyWithImpl(this._self, this._then);

  final GeneralSettingsState _self;
  final $Res Function(GeneralSettingsState) _then;

/// Create a copy of GeneralSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? maxHistoryEntries = null,Object? isApplyingHistoryLimit = null,Object? isInitialized = null,}) {
  return _then(_self.copyWith(
maxHistoryEntries: null == maxHistoryEntries ? _self.maxHistoryEntries : maxHistoryEntries // ignore: cast_nullable_to_non_nullable
as int,isApplyingHistoryLimit: null == isApplyingHistoryLimit ? _self.isApplyingHistoryLimit : isApplyingHistoryLimit // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GeneralSettingsState].
extension GeneralSettingsStatePatterns on GeneralSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeneralSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeneralSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeneralSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _GeneralSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeneralSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _GeneralSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int maxHistoryEntries,  bool isApplyingHistoryLimit,  bool isInitialized)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeneralSettingsState() when $default != null:
return $default(_that.maxHistoryEntries,_that.isApplyingHistoryLimit,_that.isInitialized);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int maxHistoryEntries,  bool isApplyingHistoryLimit,  bool isInitialized)  $default,) {final _that = this;
switch (_that) {
case _GeneralSettingsState():
return $default(_that.maxHistoryEntries,_that.isApplyingHistoryLimit,_that.isInitialized);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int maxHistoryEntries,  bool isApplyingHistoryLimit,  bool isInitialized)?  $default,) {final _that = this;
switch (_that) {
case _GeneralSettingsState() when $default != null:
return $default(_that.maxHistoryEntries,_that.isApplyingHistoryLimit,_that.isInitialized);case _:
  return null;

}
}

}

/// @nodoc


class _GeneralSettingsState implements GeneralSettingsState {
  const _GeneralSettingsState({this.maxHistoryEntries = 100, this.isApplyingHistoryLimit = false, this.isInitialized = false});
  

@override@JsonKey() final  int maxHistoryEntries;
@override@JsonKey() final  bool isApplyingHistoryLimit;
@override@JsonKey() final  bool isInitialized;

/// Create a copy of GeneralSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeneralSettingsStateCopyWith<_GeneralSettingsState> get copyWith => __$GeneralSettingsStateCopyWithImpl<_GeneralSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeneralSettingsState&&(identical(other.maxHistoryEntries, maxHistoryEntries) || other.maxHistoryEntries == maxHistoryEntries)&&(identical(other.isApplyingHistoryLimit, isApplyingHistoryLimit) || other.isApplyingHistoryLimit == isApplyingHistoryLimit)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,maxHistoryEntries,isApplyingHistoryLimit,isInitialized);

@override
String toString() {
  return 'GeneralSettingsState(maxHistoryEntries: $maxHistoryEntries, isApplyingHistoryLimit: $isApplyingHistoryLimit, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class _$GeneralSettingsStateCopyWith<$Res> implements $GeneralSettingsStateCopyWith<$Res> {
  factory _$GeneralSettingsStateCopyWith(_GeneralSettingsState value, $Res Function(_GeneralSettingsState) _then) = __$GeneralSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 int maxHistoryEntries, bool isApplyingHistoryLimit, bool isInitialized
});




}
/// @nodoc
class __$GeneralSettingsStateCopyWithImpl<$Res>
    implements _$GeneralSettingsStateCopyWith<$Res> {
  __$GeneralSettingsStateCopyWithImpl(this._self, this._then);

  final _GeneralSettingsState _self;
  final $Res Function(_GeneralSettingsState) _then;

/// Create a copy of GeneralSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? maxHistoryEntries = null,Object? isApplyingHistoryLimit = null,Object? isInitialized = null,}) {
  return _then(_GeneralSettingsState(
maxHistoryEntries: null == maxHistoryEntries ? _self.maxHistoryEntries : maxHistoryEntries // ignore: cast_nullable_to_non_nullable
as int,isApplyingHistoryLimit: null == isApplyingHistoryLimit ? _self.isApplyingHistoryLimit : isApplyingHistoryLimit // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
