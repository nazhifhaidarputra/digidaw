// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginSettingsState {

 bool get thirdPartyHostingAvailable; String get unavailableReason;
/// Create a copy of PluginSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSettingsStateCopyWith<PluginSettingsState> get copyWith => _$PluginSettingsStateCopyWithImpl<PluginSettingsState>(this as PluginSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSettingsState&&(identical(other.thirdPartyHostingAvailable, thirdPartyHostingAvailable) || other.thirdPartyHostingAvailable == thirdPartyHostingAvailable)&&(identical(other.unavailableReason, unavailableReason) || other.unavailableReason == unavailableReason));
}


@override
int get hashCode => Object.hash(runtimeType,thirdPartyHostingAvailable,unavailableReason);

@override
String toString() {
  return 'PluginSettingsState(thirdPartyHostingAvailable: $thirdPartyHostingAvailable, unavailableReason: $unavailableReason)';
}


}

/// @nodoc
abstract mixin class $PluginSettingsStateCopyWith<$Res>  {
  factory $PluginSettingsStateCopyWith(PluginSettingsState value, $Res Function(PluginSettingsState) _then) = _$PluginSettingsStateCopyWithImpl;
@useResult
$Res call({
 bool thirdPartyHostingAvailable, String unavailableReason
});




}
/// @nodoc
class _$PluginSettingsStateCopyWithImpl<$Res>
    implements $PluginSettingsStateCopyWith<$Res> {
  _$PluginSettingsStateCopyWithImpl(this._self, this._then);

  final PluginSettingsState _self;
  final $Res Function(PluginSettingsState) _then;

/// Create a copy of PluginSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? thirdPartyHostingAvailable = null,Object? unavailableReason = null,}) {
  return _then(_self.copyWith(
thirdPartyHostingAvailable: null == thirdPartyHostingAvailable ? _self.thirdPartyHostingAvailable : thirdPartyHostingAvailable // ignore: cast_nullable_to_non_nullable
as bool,unavailableReason: null == unavailableReason ? _self.unavailableReason : unavailableReason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginSettingsState].
extension PluginSettingsStatePatterns on PluginSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _PluginSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _PluginSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool thirdPartyHostingAvailable,  String unavailableReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginSettingsState() when $default != null:
return $default(_that.thirdPartyHostingAvailable,_that.unavailableReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool thirdPartyHostingAvailable,  String unavailableReason)  $default,) {final _that = this;
switch (_that) {
case _PluginSettingsState():
return $default(_that.thirdPartyHostingAvailable,_that.unavailableReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool thirdPartyHostingAvailable,  String unavailableReason)?  $default,) {final _that = this;
switch (_that) {
case _PluginSettingsState() when $default != null:
return $default(_that.thirdPartyHostingAvailable,_that.unavailableReason);case _:
  return null;

}
}

}

/// @nodoc


class _PluginSettingsState implements PluginSettingsState {
  const _PluginSettingsState({this.thirdPartyHostingAvailable = false, this.unavailableReason = 'Third-party plugin scanning is unavailable until a plugin host is ready.'});
  

@override@JsonKey() final  bool thirdPartyHostingAvailable;
@override@JsonKey() final  String unavailableReason;

/// Create a copy of PluginSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSettingsStateCopyWith<_PluginSettingsState> get copyWith => __$PluginSettingsStateCopyWithImpl<_PluginSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSettingsState&&(identical(other.thirdPartyHostingAvailable, thirdPartyHostingAvailable) || other.thirdPartyHostingAvailable == thirdPartyHostingAvailable)&&(identical(other.unavailableReason, unavailableReason) || other.unavailableReason == unavailableReason));
}


@override
int get hashCode => Object.hash(runtimeType,thirdPartyHostingAvailable,unavailableReason);

@override
String toString() {
  return 'PluginSettingsState(thirdPartyHostingAvailable: $thirdPartyHostingAvailable, unavailableReason: $unavailableReason)';
}


}

/// @nodoc
abstract mixin class _$PluginSettingsStateCopyWith<$Res> implements $PluginSettingsStateCopyWith<$Res> {
  factory _$PluginSettingsStateCopyWith(_PluginSettingsState value, $Res Function(_PluginSettingsState) _then) = __$PluginSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 bool thirdPartyHostingAvailable, String unavailableReason
});




}
/// @nodoc
class __$PluginSettingsStateCopyWithImpl<$Res>
    implements _$PluginSettingsStateCopyWith<$Res> {
  __$PluginSettingsStateCopyWithImpl(this._self, this._then);

  final _PluginSettingsState _self;
  final $Res Function(_PluginSettingsState) _then;

/// Create a copy of PluginSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? thirdPartyHostingAvailable = null,Object? unavailableReason = null,}) {
  return _then(_PluginSettingsState(
thirdPartyHostingAvailable: null == thirdPartyHostingAvailable ? _self.thirdPartyHostingAvailable : thirdPartyHostingAvailable // ignore: cast_nullable_to_non_nullable
as bool,unavailableReason: null == unavailableReason ? _self.unavailableReason : unavailableReason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
