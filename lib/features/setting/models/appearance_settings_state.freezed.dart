// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'appearance_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppearanceSettingsState {

 AppThemeMode get themeMode; AppColorPalette get colorPalette; bool get isInitialized; String? get backgroundImagePath; AppBackgroundFit get backgroundFit; double get backgroundOverlayOpacity; String? get customFontPath; String? get customFontFamily;
/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppearanceSettingsStateCopyWith<AppearanceSettingsState> get copyWith => _$AppearanceSettingsStateCopyWithImpl<AppearanceSettingsState>(this as AppearanceSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppearanceSettingsState&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.colorPalette, colorPalette) || other.colorPalette == colorPalette)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.backgroundImagePath, backgroundImagePath) || other.backgroundImagePath == backgroundImagePath)&&(identical(other.backgroundFit, backgroundFit) || other.backgroundFit == backgroundFit)&&(identical(other.backgroundOverlayOpacity, backgroundOverlayOpacity) || other.backgroundOverlayOpacity == backgroundOverlayOpacity)&&(identical(other.customFontPath, customFontPath) || other.customFontPath == customFontPath)&&(identical(other.customFontFamily, customFontFamily) || other.customFontFamily == customFontFamily));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,colorPalette,isInitialized,backgroundImagePath,backgroundFit,backgroundOverlayOpacity,customFontPath,customFontFamily);

@override
String toString() {
  return 'AppearanceSettingsState(themeMode: $themeMode, colorPalette: $colorPalette, isInitialized: $isInitialized, backgroundImagePath: $backgroundImagePath, backgroundFit: $backgroundFit, backgroundOverlayOpacity: $backgroundOverlayOpacity, customFontPath: $customFontPath, customFontFamily: $customFontFamily)';
}


}

/// @nodoc
abstract mixin class $AppearanceSettingsStateCopyWith<$Res>  {
  factory $AppearanceSettingsStateCopyWith(AppearanceSettingsState value, $Res Function(AppearanceSettingsState) _then) = _$AppearanceSettingsStateCopyWithImpl;
@useResult
$Res call({
 AppThemeMode themeMode, AppColorPalette colorPalette, bool isInitialized, String? backgroundImagePath, AppBackgroundFit backgroundFit, double backgroundOverlayOpacity, String? customFontPath, String? customFontFamily
});




}
/// @nodoc
class _$AppearanceSettingsStateCopyWithImpl<$Res>
    implements $AppearanceSettingsStateCopyWith<$Res> {
  _$AppearanceSettingsStateCopyWithImpl(this._self, this._then);

  final AppearanceSettingsState _self;
  final $Res Function(AppearanceSettingsState) _then;

/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? colorPalette = null,Object? isInitialized = null,Object? backgroundImagePath = freezed,Object? backgroundFit = null,Object? backgroundOverlayOpacity = null,Object? customFontPath = freezed,Object? customFontFamily = freezed,}) {
  return _then(_self.copyWith(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,colorPalette: null == colorPalette ? _self.colorPalette : colorPalette // ignore: cast_nullable_to_non_nullable
as AppColorPalette,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,backgroundImagePath: freezed == backgroundImagePath ? _self.backgroundImagePath : backgroundImagePath // ignore: cast_nullable_to_non_nullable
as String?,backgroundFit: null == backgroundFit ? _self.backgroundFit : backgroundFit // ignore: cast_nullable_to_non_nullable
as AppBackgroundFit,backgroundOverlayOpacity: null == backgroundOverlayOpacity ? _self.backgroundOverlayOpacity : backgroundOverlayOpacity // ignore: cast_nullable_to_non_nullable
as double,customFontPath: freezed == customFontPath ? _self.customFontPath : customFontPath // ignore: cast_nullable_to_non_nullable
as String?,customFontFamily: freezed == customFontFamily ? _self.customFontFamily : customFontFamily // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppearanceSettingsState].
extension AppearanceSettingsStatePatterns on AppearanceSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppearanceSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppearanceSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppearanceSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _AppearanceSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppearanceSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _AppearanceSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  String? customFontPath,  String? customFontFamily)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppearanceSettingsState() when $default != null:
return $default(_that.themeMode,_that.colorPalette,_that.isInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.customFontPath,_that.customFontFamily);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  String? customFontPath,  String? customFontFamily)  $default,) {final _that = this;
switch (_that) {
case _AppearanceSettingsState():
return $default(_that.themeMode,_that.colorPalette,_that.isInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.customFontPath,_that.customFontFamily);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  String? customFontPath,  String? customFontFamily)?  $default,) {final _that = this;
switch (_that) {
case _AppearanceSettingsState() when $default != null:
return $default(_that.themeMode,_that.colorPalette,_that.isInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.customFontPath,_that.customFontFamily);case _:
  return null;

}
}

}

/// @nodoc


class _AppearanceSettingsState implements AppearanceSettingsState {
  const _AppearanceSettingsState({this.themeMode = AppThemeMode.dark, this.colorPalette = AppColorPalette.purple, this.isInitialized = false, this.backgroundImagePath, this.backgroundFit = AppBackgroundFit.cover, this.backgroundOverlayOpacity = 0.35, this.customFontPath, this.customFontFamily});
  

@override@JsonKey() final  AppThemeMode themeMode;
@override@JsonKey() final  AppColorPalette colorPalette;
@override@JsonKey() final  bool isInitialized;
@override final  String? backgroundImagePath;
@override@JsonKey() final  AppBackgroundFit backgroundFit;
@override@JsonKey() final  double backgroundOverlayOpacity;
@override final  String? customFontPath;
@override final  String? customFontFamily;

/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppearanceSettingsStateCopyWith<_AppearanceSettingsState> get copyWith => __$AppearanceSettingsStateCopyWithImpl<_AppearanceSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppearanceSettingsState&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.colorPalette, colorPalette) || other.colorPalette == colorPalette)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.backgroundImagePath, backgroundImagePath) || other.backgroundImagePath == backgroundImagePath)&&(identical(other.backgroundFit, backgroundFit) || other.backgroundFit == backgroundFit)&&(identical(other.backgroundOverlayOpacity, backgroundOverlayOpacity) || other.backgroundOverlayOpacity == backgroundOverlayOpacity)&&(identical(other.customFontPath, customFontPath) || other.customFontPath == customFontPath)&&(identical(other.customFontFamily, customFontFamily) || other.customFontFamily == customFontFamily));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,colorPalette,isInitialized,backgroundImagePath,backgroundFit,backgroundOverlayOpacity,customFontPath,customFontFamily);

@override
String toString() {
  return 'AppearanceSettingsState(themeMode: $themeMode, colorPalette: $colorPalette, isInitialized: $isInitialized, backgroundImagePath: $backgroundImagePath, backgroundFit: $backgroundFit, backgroundOverlayOpacity: $backgroundOverlayOpacity, customFontPath: $customFontPath, customFontFamily: $customFontFamily)';
}


}

/// @nodoc
abstract mixin class _$AppearanceSettingsStateCopyWith<$Res> implements $AppearanceSettingsStateCopyWith<$Res> {
  factory _$AppearanceSettingsStateCopyWith(_AppearanceSettingsState value, $Res Function(_AppearanceSettingsState) _then) = __$AppearanceSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 AppThemeMode themeMode, AppColorPalette colorPalette, bool isInitialized, String? backgroundImagePath, AppBackgroundFit backgroundFit, double backgroundOverlayOpacity, String? customFontPath, String? customFontFamily
});




}
/// @nodoc
class __$AppearanceSettingsStateCopyWithImpl<$Res>
    implements _$AppearanceSettingsStateCopyWith<$Res> {
  __$AppearanceSettingsStateCopyWithImpl(this._self, this._then);

  final _AppearanceSettingsState _self;
  final $Res Function(_AppearanceSettingsState) _then;

/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? colorPalette = null,Object? isInitialized = null,Object? backgroundImagePath = freezed,Object? backgroundFit = null,Object? backgroundOverlayOpacity = null,Object? customFontPath = freezed,Object? customFontFamily = freezed,}) {
  return _then(_AppearanceSettingsState(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,colorPalette: null == colorPalette ? _self.colorPalette : colorPalette // ignore: cast_nullable_to_non_nullable
as AppColorPalette,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,backgroundImagePath: freezed == backgroundImagePath ? _self.backgroundImagePath : backgroundImagePath // ignore: cast_nullable_to_non_nullable
as String?,backgroundFit: null == backgroundFit ? _self.backgroundFit : backgroundFit // ignore: cast_nullable_to_non_nullable
as AppBackgroundFit,backgroundOverlayOpacity: null == backgroundOverlayOpacity ? _self.backgroundOverlayOpacity : backgroundOverlayOpacity // ignore: cast_nullable_to_non_nullable
as double,customFontPath: freezed == customFontPath ? _self.customFontPath : customFontPath // ignore: cast_nullable_to_non_nullable
as String?,customFontFamily: freezed == customFontFamily ? _self.customFontFamily : customFontFamily // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
