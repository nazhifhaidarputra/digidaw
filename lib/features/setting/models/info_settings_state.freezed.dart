// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'info_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InfoSettingsState {

 bool get isLoading; String? get version; String? get buildNumber; String? get errorMessage;
/// Create a copy of InfoSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InfoSettingsStateCopyWith<InfoSettingsState> get copyWith => _$InfoSettingsStateCopyWithImpl<InfoSettingsState>(this as InfoSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InfoSettingsState&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.version, version) || other.version == version)&&(identical(other.buildNumber, buildNumber) || other.buildNumber == buildNumber)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,isLoading,version,buildNumber,errorMessage);

@override
String toString() {
  return 'InfoSettingsState(isLoading: $isLoading, version: $version, buildNumber: $buildNumber, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $InfoSettingsStateCopyWith<$Res>  {
  factory $InfoSettingsStateCopyWith(InfoSettingsState value, $Res Function(InfoSettingsState) _then) = _$InfoSettingsStateCopyWithImpl;
@useResult
$Res call({
 bool isLoading, String? version, String? buildNumber, String? errorMessage
});




}
/// @nodoc
class _$InfoSettingsStateCopyWithImpl<$Res>
    implements $InfoSettingsStateCopyWith<$Res> {
  _$InfoSettingsStateCopyWithImpl(this._self, this._then);

  final InfoSettingsState _self;
  final $Res Function(InfoSettingsState) _then;

/// Create a copy of InfoSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isLoading = null,Object? version = freezed,Object? buildNumber = freezed,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,buildNumber: freezed == buildNumber ? _self.buildNumber : buildNumber // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [InfoSettingsState].
extension InfoSettingsStatePatterns on InfoSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InfoSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InfoSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InfoSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _InfoSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InfoSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _InfoSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isLoading,  String? version,  String? buildNumber,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InfoSettingsState() when $default != null:
return $default(_that.isLoading,_that.version,_that.buildNumber,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isLoading,  String? version,  String? buildNumber,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _InfoSettingsState():
return $default(_that.isLoading,_that.version,_that.buildNumber,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isLoading,  String? version,  String? buildNumber,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _InfoSettingsState() when $default != null:
return $default(_that.isLoading,_that.version,_that.buildNumber,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _InfoSettingsState implements InfoSettingsState {
  const _InfoSettingsState({this.isLoading = false, this.version, this.buildNumber, this.errorMessage});
  

@override@JsonKey() final  bool isLoading;
@override final  String? version;
@override final  String? buildNumber;
@override final  String? errorMessage;

/// Create a copy of InfoSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InfoSettingsStateCopyWith<_InfoSettingsState> get copyWith => __$InfoSettingsStateCopyWithImpl<_InfoSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InfoSettingsState&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.version, version) || other.version == version)&&(identical(other.buildNumber, buildNumber) || other.buildNumber == buildNumber)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,isLoading,version,buildNumber,errorMessage);

@override
String toString() {
  return 'InfoSettingsState(isLoading: $isLoading, version: $version, buildNumber: $buildNumber, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$InfoSettingsStateCopyWith<$Res> implements $InfoSettingsStateCopyWith<$Res> {
  factory _$InfoSettingsStateCopyWith(_InfoSettingsState value, $Res Function(_InfoSettingsState) _then) = __$InfoSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 bool isLoading, String? version, String? buildNumber, String? errorMessage
});




}
/// @nodoc
class __$InfoSettingsStateCopyWithImpl<$Res>
    implements _$InfoSettingsStateCopyWith<$Res> {
  __$InfoSettingsStateCopyWithImpl(this._self, this._then);

  final _InfoSettingsState _self;
  final $Res Function(_InfoSettingsState) _then;

/// Create a copy of InfoSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isLoading = null,Object? version = freezed,Object? buildNumber = freezed,Object? errorMessage = freezed,}) {
  return _then(_InfoSettingsState(
isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,buildNumber: freezed == buildNumber ? _self.buildNumber : buildNumber // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
