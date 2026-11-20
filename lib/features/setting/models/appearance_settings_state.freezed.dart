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
mixin _$AppFontChoice {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppFontChoice);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AppFontChoice()';
}


}

/// @nodoc
class $AppFontChoiceCopyWith<$Res>  {
$AppFontChoiceCopyWith(AppFontChoice _, $Res Function(AppFontChoice) __);
}


/// Adds pattern-matching-related methods to [AppFontChoice].
extension AppFontChoicePatterns on AppFontChoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SystemFontChoice value)?  system,TResult Function( BundledFontChoice value)?  bundled,TResult Function( FileFontChoice value)?  file,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SystemFontChoice() when system != null:
return system(_that);case BundledFontChoice() when bundled != null:
return bundled(_that);case FileFontChoice() when file != null:
return file(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SystemFontChoice value)  system,required TResult Function( BundledFontChoice value)  bundled,required TResult Function( FileFontChoice value)  file,}){
final _that = this;
switch (_that) {
case SystemFontChoice():
return system(_that);case BundledFontChoice():
return bundled(_that);case FileFontChoice():
return file(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SystemFontChoice value)?  system,TResult? Function( BundledFontChoice value)?  bundled,TResult? Function( FileFontChoice value)?  file,}){
final _that = this;
switch (_that) {
case SystemFontChoice() when system != null:
return system(_that);case BundledFontChoice() when bundled != null:
return bundled(_that);case FileFontChoice() when file != null:
return file(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  system,TResult Function( String family)?  bundled,TResult Function( String path)?  file,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SystemFontChoice() when system != null:
return system();case BundledFontChoice() when bundled != null:
return bundled(_that.family);case FileFontChoice() when file != null:
return file(_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  system,required TResult Function( String family)  bundled,required TResult Function( String path)  file,}) {final _that = this;
switch (_that) {
case SystemFontChoice():
return system();case BundledFontChoice():
return bundled(_that.family);case FileFontChoice():
return file(_that.path);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  system,TResult? Function( String family)?  bundled,TResult? Function( String path)?  file,}) {final _that = this;
switch (_that) {
case SystemFontChoice() when system != null:
return system();case BundledFontChoice() when bundled != null:
return bundled(_that.family);case FileFontChoice() when file != null:
return file(_that.path);case _:
  return null;

}
}

}

/// @nodoc


class SystemFontChoice implements AppFontChoice {
  const SystemFontChoice();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemFontChoice);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AppFontChoice.system()';
}


}




/// @nodoc


class BundledFontChoice implements AppFontChoice {
  const BundledFontChoice(this.family);
  

 final  String family;

/// Create a copy of AppFontChoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BundledFontChoiceCopyWith<BundledFontChoice> get copyWith => _$BundledFontChoiceCopyWithImpl<BundledFontChoice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BundledFontChoice&&(identical(other.family, family) || other.family == family));
}


@override
int get hashCode => Object.hash(runtimeType,family);

@override
String toString() {
  return 'AppFontChoice.bundled(family: $family)';
}


}

/// @nodoc
abstract mixin class $BundledFontChoiceCopyWith<$Res> implements $AppFontChoiceCopyWith<$Res> {
  factory $BundledFontChoiceCopyWith(BundledFontChoice value, $Res Function(BundledFontChoice) _then) = _$BundledFontChoiceCopyWithImpl;
@useResult
$Res call({
 String family
});




}
/// @nodoc
class _$BundledFontChoiceCopyWithImpl<$Res>
    implements $BundledFontChoiceCopyWith<$Res> {
  _$BundledFontChoiceCopyWithImpl(this._self, this._then);

  final BundledFontChoice _self;
  final $Res Function(BundledFontChoice) _then;

/// Create a copy of AppFontChoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? family = null,}) {
  return _then(BundledFontChoice(
null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FileFontChoice implements AppFontChoice {
  const FileFontChoice(this.path);
  

 final  String path;

/// Create a copy of AppFontChoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileFontChoiceCopyWith<FileFontChoice> get copyWith => _$FileFontChoiceCopyWithImpl<FileFontChoice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileFontChoice&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'AppFontChoice.file(path: $path)';
}


}

/// @nodoc
abstract mixin class $FileFontChoiceCopyWith<$Res> implements $AppFontChoiceCopyWith<$Res> {
  factory $FileFontChoiceCopyWith(FileFontChoice value, $Res Function(FileFontChoice) _then) = _$FileFontChoiceCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$FileFontChoiceCopyWithImpl<$Res>
    implements $FileFontChoiceCopyWith<$Res> {
  _$FileFontChoiceCopyWithImpl(this._self, this._then);

  final FileFontChoice _self;
  final $Res Function(FileFontChoice) _then;

/// Create a copy of AppFontChoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(FileFontChoice(
null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$AppearanceSettingsState {

 AppThemeMode get themeMode; AppColorPalette get colorPalette; bool get isInitialized; String? get backgroundImagePath; AppBackgroundFit get backgroundFit; double get backgroundOverlayOpacity; AppFontChoice get font;/// Family the theme uses for [font]; null leaves the platform's default
/// font, as [AppFontChoice.system] does when the desktop names none.
 String? get fontFamily;/// Loaded colour themes by source: a bundled asset key or a file path.
 IMap<String, AppColorTheme> get colorThemes;/// Source of the active colour theme. Without one, the colours come from
/// [themeMode] and [colorPalette].
 String? get colorThemeSource;/// Theme files the user loaded, in the order they were loaded.
 IList<String> get customColorThemePaths;
/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppearanceSettingsStateCopyWith<AppearanceSettingsState> get copyWith => _$AppearanceSettingsStateCopyWithImpl<AppearanceSettingsState>(this as AppearanceSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppearanceSettingsState&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.colorPalette, colorPalette) || other.colorPalette == colorPalette)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.backgroundImagePath, backgroundImagePath) || other.backgroundImagePath == backgroundImagePath)&&(identical(other.backgroundFit, backgroundFit) || other.backgroundFit == backgroundFit)&&(identical(other.backgroundOverlayOpacity, backgroundOverlayOpacity) || other.backgroundOverlayOpacity == backgroundOverlayOpacity)&&(identical(other.font, font) || other.font == font)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.colorThemes, colorThemes) || other.colorThemes == colorThemes)&&(identical(other.colorThemeSource, colorThemeSource) || other.colorThemeSource == colorThemeSource)&&const DeepCollectionEquality().equals(other.customColorThemePaths, customColorThemePaths));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,colorPalette,isInitialized,backgroundImagePath,backgroundFit,backgroundOverlayOpacity,font,fontFamily,colorThemes,colorThemeSource,const DeepCollectionEquality().hash(customColorThemePaths));

@override
String toString() {
  return 'AppearanceSettingsState(themeMode: $themeMode, colorPalette: $colorPalette, isInitialized: $isInitialized, backgroundImagePath: $backgroundImagePath, backgroundFit: $backgroundFit, backgroundOverlayOpacity: $backgroundOverlayOpacity, font: $font, fontFamily: $fontFamily, colorThemes: $colorThemes, colorThemeSource: $colorThemeSource, customColorThemePaths: $customColorThemePaths)';
}


}

/// @nodoc
abstract mixin class $AppearanceSettingsStateCopyWith<$Res>  {
  factory $AppearanceSettingsStateCopyWith(AppearanceSettingsState value, $Res Function(AppearanceSettingsState) _then) = _$AppearanceSettingsStateCopyWithImpl;
@useResult
$Res call({
 AppThemeMode themeMode, AppColorPalette colorPalette, bool isInitialized, String? backgroundImagePath, AppBackgroundFit backgroundFit, double backgroundOverlayOpacity, AppFontChoice font, String? fontFamily, IMap<String, AppColorTheme> colorThemes, String? colorThemeSource, IList<String> customColorThemePaths
});


$AppFontChoiceCopyWith<$Res> get font;

}
/// @nodoc
class _$AppearanceSettingsStateCopyWithImpl<$Res>
    implements $AppearanceSettingsStateCopyWith<$Res> {
  _$AppearanceSettingsStateCopyWithImpl(this._self, this._then);

  final AppearanceSettingsState _self;
  final $Res Function(AppearanceSettingsState) _then;

/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? colorPalette = null,Object? isInitialized = null,Object? backgroundImagePath = freezed,Object? backgroundFit = null,Object? backgroundOverlayOpacity = null,Object? font = null,Object? fontFamily = freezed,Object? colorThemes = null,Object? colorThemeSource = freezed,Object? customColorThemePaths = null,}) {
  return _then(_self.copyWith(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,colorPalette: null == colorPalette ? _self.colorPalette : colorPalette // ignore: cast_nullable_to_non_nullable
as AppColorPalette,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,backgroundImagePath: freezed == backgroundImagePath ? _self.backgroundImagePath : backgroundImagePath // ignore: cast_nullable_to_non_nullable
as String?,backgroundFit: null == backgroundFit ? _self.backgroundFit : backgroundFit // ignore: cast_nullable_to_non_nullable
as AppBackgroundFit,backgroundOverlayOpacity: null == backgroundOverlayOpacity ? _self.backgroundOverlayOpacity : backgroundOverlayOpacity // ignore: cast_nullable_to_non_nullable
as double,font: null == font ? _self.font : font // ignore: cast_nullable_to_non_nullable
as AppFontChoice,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,colorThemes: null == colorThemes ? _self.colorThemes : colorThemes // ignore: cast_nullable_to_non_nullable
as IMap<String, AppColorTheme>,colorThemeSource: freezed == colorThemeSource ? _self.colorThemeSource : colorThemeSource // ignore: cast_nullable_to_non_nullable
as String?,customColorThemePaths: null == customColorThemePaths ? _self.customColorThemePaths : customColorThemePaths // ignore: cast_nullable_to_non_nullable
as IList<String>,
  ));
}
/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppFontChoiceCopyWith<$Res> get font {
  
  return $AppFontChoiceCopyWith<$Res>(_self.font, (value) {
    return _then(_self.copyWith(font: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  AppFontChoice font,  String? fontFamily,  IMap<String, AppColorTheme> colorThemes,  String? colorThemeSource,  IList<String> customColorThemePaths)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppearanceSettingsState() when $default != null:
return $default(_that.themeMode,_that.colorPalette,_that.isInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.font,_that.fontFamily,_that.colorThemes,_that.colorThemeSource,_that.customColorThemePaths);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  AppFontChoice font,  String? fontFamily,  IMap<String, AppColorTheme> colorThemes,  String? colorThemeSource,  IList<String> customColorThemePaths)  $default,) {final _that = this;
switch (_that) {
case _AppearanceSettingsState():
return $default(_that.themeMode,_that.colorPalette,_that.isInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.font,_that.fontFamily,_that.colorThemes,_that.colorThemeSource,_that.customColorThemePaths);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AppThemeMode themeMode,  AppColorPalette colorPalette,  bool isInitialized,  String? backgroundImagePath,  AppBackgroundFit backgroundFit,  double backgroundOverlayOpacity,  AppFontChoice font,  String? fontFamily,  IMap<String, AppColorTheme> colorThemes,  String? colorThemeSource,  IList<String> customColorThemePaths)?  $default,) {final _that = this;
switch (_that) {
case _AppearanceSettingsState() when $default != null:
return $default(_that.themeMode,_that.colorPalette,_that.isInitialized,_that.backgroundImagePath,_that.backgroundFit,_that.backgroundOverlayOpacity,_that.font,_that.fontFamily,_that.colorThemes,_that.colorThemeSource,_that.customColorThemePaths);case _:
  return null;

}
}

}

/// @nodoc


class _AppearanceSettingsState extends AppearanceSettingsState {
  const _AppearanceSettingsState({this.themeMode = AppThemeMode.dark, this.colorPalette = AppColorPalette.purple, this.isInitialized = false, this.backgroundImagePath, this.backgroundFit = AppBackgroundFit.cover, this.backgroundOverlayOpacity = 0.35, this.font = AppFontChoice.defaultFont, this.fontFamily = AppFonts.defaultFamily, this.colorThemes = const IMapConst({}), this.colorThemeSource, this.customColorThemePaths = const IListConst([])}): super._();
  

@override@JsonKey() final  AppThemeMode themeMode;
@override@JsonKey() final  AppColorPalette colorPalette;
@override@JsonKey() final  bool isInitialized;
@override final  String? backgroundImagePath;
@override@JsonKey() final  AppBackgroundFit backgroundFit;
@override@JsonKey() final  double backgroundOverlayOpacity;
@override@JsonKey() final  AppFontChoice font;
/// Family the theme uses for [font]; null leaves the platform's default
/// font, as [AppFontChoice.system] does when the desktop names none.
@override@JsonKey() final  String? fontFamily;
/// Loaded colour themes by source: a bundled asset key or a file path.
@override@JsonKey() final  IMap<String, AppColorTheme> colorThemes;
/// Source of the active colour theme. Without one, the colours come from
/// [themeMode] and [colorPalette].
@override final  String? colorThemeSource;
/// Theme files the user loaded, in the order they were loaded.
@override@JsonKey() final  IList<String> customColorThemePaths;

/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppearanceSettingsStateCopyWith<_AppearanceSettingsState> get copyWith => __$AppearanceSettingsStateCopyWithImpl<_AppearanceSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppearanceSettingsState&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.colorPalette, colorPalette) || other.colorPalette == colorPalette)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.backgroundImagePath, backgroundImagePath) || other.backgroundImagePath == backgroundImagePath)&&(identical(other.backgroundFit, backgroundFit) || other.backgroundFit == backgroundFit)&&(identical(other.backgroundOverlayOpacity, backgroundOverlayOpacity) || other.backgroundOverlayOpacity == backgroundOverlayOpacity)&&(identical(other.font, font) || other.font == font)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.colorThemes, colorThemes) || other.colorThemes == colorThemes)&&(identical(other.colorThemeSource, colorThemeSource) || other.colorThemeSource == colorThemeSource)&&const DeepCollectionEquality().equals(other.customColorThemePaths, customColorThemePaths));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,colorPalette,isInitialized,backgroundImagePath,backgroundFit,backgroundOverlayOpacity,font,fontFamily,colorThemes,colorThemeSource,const DeepCollectionEquality().hash(customColorThemePaths));

@override
String toString() {
  return 'AppearanceSettingsState(themeMode: $themeMode, colorPalette: $colorPalette, isInitialized: $isInitialized, backgroundImagePath: $backgroundImagePath, backgroundFit: $backgroundFit, backgroundOverlayOpacity: $backgroundOverlayOpacity, font: $font, fontFamily: $fontFamily, colorThemes: $colorThemes, colorThemeSource: $colorThemeSource, customColorThemePaths: $customColorThemePaths)';
}


}

/// @nodoc
abstract mixin class _$AppearanceSettingsStateCopyWith<$Res> implements $AppearanceSettingsStateCopyWith<$Res> {
  factory _$AppearanceSettingsStateCopyWith(_AppearanceSettingsState value, $Res Function(_AppearanceSettingsState) _then) = __$AppearanceSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 AppThemeMode themeMode, AppColorPalette colorPalette, bool isInitialized, String? backgroundImagePath, AppBackgroundFit backgroundFit, double backgroundOverlayOpacity, AppFontChoice font, String? fontFamily, IMap<String, AppColorTheme> colorThemes, String? colorThemeSource, IList<String> customColorThemePaths
});


@override $AppFontChoiceCopyWith<$Res> get font;

}
/// @nodoc
class __$AppearanceSettingsStateCopyWithImpl<$Res>
    implements _$AppearanceSettingsStateCopyWith<$Res> {
  __$AppearanceSettingsStateCopyWithImpl(this._self, this._then);

  final _AppearanceSettingsState _self;
  final $Res Function(_AppearanceSettingsState) _then;

/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? colorPalette = null,Object? isInitialized = null,Object? backgroundImagePath = freezed,Object? backgroundFit = null,Object? backgroundOverlayOpacity = null,Object? font = null,Object? fontFamily = freezed,Object? colorThemes = null,Object? colorThemeSource = freezed,Object? customColorThemePaths = null,}) {
  return _then(_AppearanceSettingsState(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,colorPalette: null == colorPalette ? _self.colorPalette : colorPalette // ignore: cast_nullable_to_non_nullable
as AppColorPalette,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,backgroundImagePath: freezed == backgroundImagePath ? _self.backgroundImagePath : backgroundImagePath // ignore: cast_nullable_to_non_nullable
as String?,backgroundFit: null == backgroundFit ? _self.backgroundFit : backgroundFit // ignore: cast_nullable_to_non_nullable
as AppBackgroundFit,backgroundOverlayOpacity: null == backgroundOverlayOpacity ? _self.backgroundOverlayOpacity : backgroundOverlayOpacity // ignore: cast_nullable_to_non_nullable
as double,font: null == font ? _self.font : font // ignore: cast_nullable_to_non_nullable
as AppFontChoice,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,colorThemes: null == colorThemes ? _self.colorThemes : colorThemes // ignore: cast_nullable_to_non_nullable
as IMap<String, AppColorTheme>,colorThemeSource: freezed == colorThemeSource ? _self.colorThemeSource : colorThemeSource // ignore: cast_nullable_to_non_nullable
as String?,customColorThemePaths: null == customColorThemePaths ? _self.customColorThemePaths : customColorThemePaths // ignore: cast_nullable_to_non_nullable
as IList<String>,
  ));
}

/// Create a copy of AppearanceSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppFontChoiceCopyWith<$Res> get font {
  
  return $AppFontChoiceCopyWith<$Res>(_self.font, (value) {
    return _then(_self.copyWith(font: value));
  });
}
}

// dart format on
