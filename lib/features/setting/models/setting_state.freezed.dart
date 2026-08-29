// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setting_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingState {

 SettingMenu get selectedMenu; int get maxHistoryEntries; bool get isApplyingHistoryLimit; bool get isInitialized; AppThemeMode get themeMode; AppColorPalette get colorPalette; bool get isAppearanceInitialized; String? get backgroundImagePath; AppBackgroundFit get backgroundFit; double get backgroundOverlayOpacity; String? get customFontPath; String? get customFontFamily;
/// Create a copy of SettingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingStateCopyWith<SettingState> get copyWith => _$SettingStateCopyWithImpl<SettingState>(this as SettingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingState&&(identical(other.selectedMenu, selectedMenu) || other.selectedMenu == selectedMenu)&&(identical(other.maxHistoryEntries, maxHistoryEntries) || other.maxHistoryEntries == maxHistoryEntries)&&(identical(other.isApplyingHistoryLimit, isApplyingHistoryLimit) || other.isApplyingHistoryLimit == isApplyingHistoryLimit)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.colorPalette, colorPalette) || other.colorPalette == colorPalette)&&(identical(other.isAppearanceInitialized, isAppearanceInitialized) || other.isAppearanceInitialized == isAppearanceInitialized)&&(identical(other.backgroundImagePath, backgroundImagePath) || other.backgroundImagePath == backgroundImagePath)&&(identical(other.backgroundFit, backgroundFit) || other.backgroundFit == backgroundFit)&&(identical(other.backgroundOverlayOpacity, backgroundOverlayOpacity) || other.backgroundOverlayOpacity == backgroundOverlayOpacity)&&(identical(other.customFontPath, customFontPath) || other.customFontPath == customFontPath)&&(identical(other.customFontFamily, customFontFamily) || other.customFontFamily == customFontFamily));
}


@override
int get hashCode => Object.hash(runtimeType,selectedMenu,maxHistoryEntries,isApplyingHistoryLimit,isInitialized,themeMode,colorPalette,isAppearanceInitialized,backgroundImagePath,backgroundFit,backgroundOverlayOpacity,customFontPath,customFontFamily);

@override
String toString() {
  return 'SettingState(selectedMenu: $selectedMenu, maxHistoryEntries: $maxHistoryEntries, isApplyingHistoryLimit: $isApplyingHistoryLimit, isInitialized: $isInitialized, themeMode: $themeMode, colorPalette: $colorPalette, isAppearanceInitialized: $isAppearanceInitialized, backgroundImagePath: $backgroundImagePath, backgroundFit: $backgroundFit, backgroundOverlayOpacity: $backgroundOverlayOpacity, customFontPath: $customFontPath, customFontFamily: $customFontFamily)';
}


}

/// @nodoc
abstract mixin class $SettingStateCopyWith<$Res>  {
  factory $SettingStateCopyWith(SettingState value, $Res Function(SettingState) _then) = _$SettingStateCopyWithImpl;
@useResult
$Res call({
 SettingMenu selectedMenu, int maxHistoryEntries, bool isApplyingHistoryLimit, bool isInitialized, AppThemeMode themeMode, AppColorPalette colorPalette, bool isAppearanceInitialized, String? backgroundImagePath, AppBackgroundFit backgroundFit, double backgroundOverlayOpacity, String? customFontPath, String? customFontFamily
});




}
/// @nodoc
class _$SettingStateCopyWithImpl<$Res>
    implements $SettingStateCopyWith<$Res> {
  _$SettingStateCopyWithImpl(this._self, this._then);

  final SettingState _self;
  final $Res Function(SettingState) _then;

/// Create a copy of SettingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedMenu = null,Object? maxHistoryEntries = null,Object? isApplyingHistoryLimit = null,Object? isInitialized = null,Object? themeMode = null,Object? colorPalette = null,Object? isAppearanceInitialized = null,Object? backgroundImagePath = freezed,Object? backgroundFit = null,Object? backgroundOverlayOpacity = null,Object? customFontPath = freezed,Object? customFontFamily = freezed,}) {
  return _then(_self.copyWith(
selectedMenu: null == selectedMenu ? _self.selectedMenu : selectedMenu // ignore: cast_nullable_to_non_nullable
as SettingMenu,maxHistoryEntries: null == maxHistoryEntries ? _self.maxHistoryEntries : maxHistoryEntries // ignore: cast_nullable_to_non_nullable
as int,isApplyingHistoryLimit: null == isApplyingHistoryLimit ? _self.isApplyingHistoryLimit : isApplyingHistoryLimit // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,colorPalette: null == colorPalette ? _self.colorPalette : colorPalette // ignore: cast_nullable_to_non_nullable
as AppColorPalette,isAppearanceInitialized: null == isAppearanceInitialized ? _self.isAppearanceInitialized : isAppearanceInitialized // ignore: cast_nullable_to_non_nullable
as bool,backgroundImagePath: freezed == backgroundImagePath ? _self.backgroundImagePath : backgroundImagePath // ignore: cast_nullable_to_non_nullable
as String?,backgroundFit: null == backgroundFit ? _self.backgroundFit : backgroundFit // ignore: cast_nullable_to_non_nullable
as AppBackgroundFit,backgroundOverlayOpacity: null == backgroundOverlayOpacity ? _self.backgroundOverlayOpacity : backgroundOverlayOpacity // ignore: cast_nullable_to_non_nullable
as double,customFontPath: freezed == customFontPath ? _self.customFontPath : customFontPath // ignore: cast_nullable_to_non_nullable
as String?,customFontFamily: freezed == customFontFamily ? _self.customFontFamily : customFontFamily // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingState].
extension SettingStatePatterns on SettingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingState value)  $default,){
final _that = this;
switch (_that) {
case _SettingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingState value)?  $default,){
final _that = this;
switch (_that) {
case _SettingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SettingMenu selectedMenu,  int maxHistoryEntries,  bool isApplyingHistoryLimit,  bool isInitialized,  AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isAppearanceInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  String? customFontPath,  String? customFontFamily)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingState() when $default != null:
return $default(_that.selectedMenu,_that.maxHistoryEntries,_that.isApplyingHistoryLimit,_that.isInitialized,_that.themeMode,_that.colorPalette,_that.isAppearanceInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.customFontPath,_that.customFontFamily);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SettingMenu selectedMenu,  int maxHistoryEntries,  bool isApplyingHistoryLimit,  bool isInitialized,  AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isAppearanceInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  String? customFontPath,  String? customFontFamily)  $default,) {final _that = this;
switch (_that) {
case _SettingState():
return $default(_that.selectedMenu,_that.maxHistoryEntries,_that.isApplyingHistoryLimit,_that.isInitialized,_that.themeMode,_that.colorPalette,_that.isAppearanceInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.customFontPath,_that.customFontFamily);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SettingMenu selectedMenu,  int maxHistoryEntries,  bool isApplyingHistoryLimit,  bool isInitialized,  AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isAppearanceInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  String? customFontPath,  String? customFontFamily)?  $default,) {final _that = this;
switch (_that) {
case _SettingState() when $default != null:
return $default(_that.selectedMenu,_that.maxHistoryEntries,_that.isApplyingHistoryLimit,_that.isInitialized,_that.themeMode,_that.colorPalette,_that.isAppearanceInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.customFontPath,_that.customFontFamily);case _:
  return null;

}
}

}

/// @nodoc


class _SettingState implements SettingState {
  const _SettingState({this.selectedMenu = SettingMenu.general, this.maxHistoryEntries = 100, this.isApplyingHistoryLimit = false, this.isInitialized = false, this.themeMode = AppThemeMode.dark, this.colorPalette = AppColorPalette.purple, this.isAppearanceInitialized = false, this.backgroundImagePath, this.backgroundFit = AppBackgroundFit.cover, this.backgroundOverlayOpacity = 0.35, this.customFontPath, this.customFontFamily});
  

@override@JsonKey() final  SettingMenu selectedMenu;
@override@JsonKey() final  int maxHistoryEntries;
@override@JsonKey() final  bool isApplyingHistoryLimit;
@override@JsonKey() final  bool isInitialized;
@override@JsonKey() final  AppThemeMode themeMode;
@override@JsonKey() final  AppColorPalette colorPalette;
@override@JsonKey() final  bool isAppearanceInitialized;
@override final  String? backgroundImagePath;
@override@JsonKey() final  AppBackgroundFit backgroundFit;
@override@JsonKey() final  double backgroundOverlayOpacity;
@override final  String? customFontPath;
@override final  String? customFontFamily;

/// Create a copy of SettingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingStateCopyWith<_SettingState> get copyWith => __$SettingStateCopyWithImpl<_SettingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingState&&(identical(other.selectedMenu, selectedMenu) || other.selectedMenu == selectedMenu)&&(identical(other.maxHistoryEntries, maxHistoryEntries) || other.maxHistoryEntries == maxHistoryEntries)&&(identical(other.isApplyingHistoryLimit, isApplyingHistoryLimit) || other.isApplyingHistoryLimit == isApplyingHistoryLimit)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.colorPalette, colorPalette) || other.colorPalette == colorPalette)&&(identical(other.isAppearanceInitialized, isAppearanceInitialized) || other.isAppearanceInitialized == isAppearanceInitialized)&&(identical(other.backgroundImagePath, backgroundImagePath) || other.backgroundImagePath == backgroundImagePath)&&(identical(other.backgroundFit, backgroundFit) || other.backgroundFit == backgroundFit)&&(identical(other.backgroundOverlayOpacity, backgroundOverlayOpacity) || other.backgroundOverlayOpacity == backgroundOverlayOpacity)&&(identical(other.customFontPath, customFontPath) || other.customFontPath == customFontPath)&&(identical(other.customFontFamily, customFontFamily) || other.customFontFamily == customFontFamily));
}


@override
int get hashCode => Object.hash(runtimeType,selectedMenu,maxHistoryEntries,isApplyingHistoryLimit,isInitialized,themeMode,colorPalette,isAppearanceInitialized,backgroundImagePath,backgroundFit,backgroundOverlayOpacity,customFontPath,customFontFamily);

@override
String toString() {
  return 'SettingState(selectedMenu: $selectedMenu, maxHistoryEntries: $maxHistoryEntries, isApplyingHistoryLimit: $isApplyingHistoryLimit, isInitialized: $isInitialized, themeMode: $themeMode, colorPalette: $colorPalette, isAppearanceInitialized: $isAppearanceInitialized, backgroundImagePath: $backgroundImagePath, backgroundFit: $backgroundFit, backgroundOverlayOpacity: $backgroundOverlayOpacity, customFontPath: $customFontPath, customFontFamily: $customFontFamily)';
}


}

/// @nodoc
abstract mixin class _$SettingStateCopyWith<$Res> implements $SettingStateCopyWith<$Res> {
  factory _$SettingStateCopyWith(_SettingState value, $Res Function(_SettingState) _then) = __$SettingStateCopyWithImpl;
@override @useResult
$Res call({
 SettingMenu selectedMenu, int maxHistoryEntries, bool isApplyingHistoryLimit, bool isInitialized, AppThemeMode themeMode, AppColorPalette colorPalette, bool isAppearanceInitialized, String? backgroundImagePath, AppBackgroundFit backgroundFit, double backgroundOverlayOpacity, String? customFontPath, String? customFontFamily
});




}
/// @nodoc
class __$SettingStateCopyWithImpl<$Res>
    implements _$SettingStateCopyWith<$Res> {
  __$SettingStateCopyWithImpl(this._self, this._then);

  final _SettingState _self;
  final $Res Function(_SettingState) _then;

/// Create a copy of SettingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedMenu = null,Object? maxHistoryEntries = null,Object? isApplyingHistoryLimit = null,Object? isInitialized = null,Object? themeMode = null,Object? colorPalette = null,Object? isAppearanceInitialized = null,Object? backgroundImagePath = freezed,Object? backgroundFit = null,Object? backgroundOverlayOpacity = null,Object? customFontPath = freezed,Object? customFontFamily = freezed,}) {
  return _then(_SettingState(
selectedMenu: null == selectedMenu ? _self.selectedMenu : selectedMenu // ignore: cast_nullable_to_non_nullable
as SettingMenu,maxHistoryEntries: null == maxHistoryEntries ? _self.maxHistoryEntries : maxHistoryEntries // ignore: cast_nullable_to_non_nullable
as int,isApplyingHistoryLimit: null == isApplyingHistoryLimit ? _self.isApplyingHistoryLimit : isApplyingHistoryLimit // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,colorPalette: null == colorPalette ? _self.colorPalette : colorPalette // ignore: cast_nullable_to_non_nullable
as AppColorPalette,isAppearanceInitialized: null == isAppearanceInitialized ? _self.isAppearanceInitialized : isAppearanceInitialized // ignore: cast_nullable_to_non_nullable
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
