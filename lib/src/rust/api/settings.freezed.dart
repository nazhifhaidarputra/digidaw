// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiAppearanceSettings {

 UiThemeMode get themeMode; UiColorPalette get colorPalette; String? get backgroundImage; UiBackgroundFit get backgroundFit; double get backgroundOverlay; String? get fontPath; String? get fontFamily; UiColorThemeChoice get colorTheme; List<String> get customColorThemePaths;
/// Create a copy of UiAppearanceSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiAppearanceSettingsCopyWith<UiAppearanceSettings> get copyWith => _$UiAppearanceSettingsCopyWithImpl<UiAppearanceSettings>(this as UiAppearanceSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiAppearanceSettings&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.colorPalette, colorPalette) || other.colorPalette == colorPalette)&&(identical(other.backgroundImage, backgroundImage) || other.backgroundImage == backgroundImage)&&(identical(other.backgroundFit, backgroundFit) || other.backgroundFit == backgroundFit)&&(identical(other.backgroundOverlay, backgroundOverlay) || other.backgroundOverlay == backgroundOverlay)&&(identical(other.fontPath, fontPath) || other.fontPath == fontPath)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.colorTheme, colorTheme) || other.colorTheme == colorTheme)&&const DeepCollectionEquality().equals(other.customColorThemePaths, customColorThemePaths));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,colorPalette,backgroundImage,backgroundFit,backgroundOverlay,fontPath,fontFamily,colorTheme,const DeepCollectionEquality().hash(customColorThemePaths));

@override
String toString() {
  return 'UiAppearanceSettings(themeMode: $themeMode, colorPalette: $colorPalette, backgroundImage: $backgroundImage, backgroundFit: $backgroundFit, backgroundOverlay: $backgroundOverlay, fontPath: $fontPath, fontFamily: $fontFamily, colorTheme: $colorTheme, customColorThemePaths: $customColorThemePaths)';
}


}

/// @nodoc
abstract mixin class $UiAppearanceSettingsCopyWith<$Res>  {
  factory $UiAppearanceSettingsCopyWith(UiAppearanceSettings value, $Res Function(UiAppearanceSettings) _then) = _$UiAppearanceSettingsCopyWithImpl;
@useResult
$Res call({
 UiThemeMode themeMode, UiColorPalette colorPalette, String? backgroundImage, UiBackgroundFit backgroundFit, double backgroundOverlay, String? fontPath, String? fontFamily, UiColorThemeChoice colorTheme, List<String> customColorThemePaths
});


$UiColorThemeChoiceCopyWith<$Res> get colorTheme;

}
/// @nodoc
class _$UiAppearanceSettingsCopyWithImpl<$Res>
    implements $UiAppearanceSettingsCopyWith<$Res> {
  _$UiAppearanceSettingsCopyWithImpl(this._self, this._then);

  final UiAppearanceSettings _self;
  final $Res Function(UiAppearanceSettings) _then;

/// Create a copy of UiAppearanceSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? colorPalette = null,Object? backgroundImage = freezed,Object? backgroundFit = null,Object? backgroundOverlay = null,Object? fontPath = freezed,Object? fontFamily = freezed,Object? colorTheme = null,Object? customColorThemePaths = null,}) {
  return _then(_self.copyWith(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as UiThemeMode,colorPalette: null == colorPalette ? _self.colorPalette : colorPalette // ignore: cast_nullable_to_non_nullable
as UiColorPalette,backgroundImage: freezed == backgroundImage ? _self.backgroundImage : backgroundImage // ignore: cast_nullable_to_non_nullable
as String?,backgroundFit: null == backgroundFit ? _self.backgroundFit : backgroundFit // ignore: cast_nullable_to_non_nullable
as UiBackgroundFit,backgroundOverlay: null == backgroundOverlay ? _self.backgroundOverlay : backgroundOverlay // ignore: cast_nullable_to_non_nullable
as double,fontPath: freezed == fontPath ? _self.fontPath : fontPath // ignore: cast_nullable_to_non_nullable
as String?,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,colorTheme: null == colorTheme ? _self.colorTheme : colorTheme // ignore: cast_nullable_to_non_nullable
as UiColorThemeChoice,customColorThemePaths: null == customColorThemePaths ? _self.customColorThemePaths : customColorThemePaths // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of UiAppearanceSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiColorThemeChoiceCopyWith<$Res> get colorTheme {
  
  return $UiColorThemeChoiceCopyWith<$Res>(_self.colorTheme, (value) {
    return _then(_self.copyWith(colorTheme: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiAppearanceSettings].
extension UiAppearanceSettingsPatterns on UiAppearanceSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiAppearanceSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiAppearanceSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiAppearanceSettings value)  $default,){
final _that = this;
switch (_that) {
case _UiAppearanceSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiAppearanceSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UiAppearanceSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiThemeMode themeMode,  UiColorPalette colorPalette,  String? backgroundImage,  UiBackgroundFit backgroundFit,  double backgroundOverlay,  String? fontPath,  String? fontFamily,  UiColorThemeChoice colorTheme,  List<String> customColorThemePaths)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiAppearanceSettings() when $default != null:
return $default(_that.themeMode,_that.colorPalette,_that.backgroundImage,_that.backgroundFit,_that.backgroundOverlay,_that.fontPath,_that.fontFamily,_that.colorTheme,_that.customColorThemePaths);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiThemeMode themeMode,  UiColorPalette colorPalette,  String? backgroundImage,  UiBackgroundFit backgroundFit,  double backgroundOverlay,  String? fontPath,  String? fontFamily,  UiColorThemeChoice colorTheme,  List<String> customColorThemePaths)  $default,) {final _that = this;
switch (_that) {
case _UiAppearanceSettings():
return $default(_that.themeMode,_that.colorPalette,_that.backgroundImage,_that.backgroundFit,_that.backgroundOverlay,_that.fontPath,_that.fontFamily,_that.colorTheme,_that.customColorThemePaths);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiThemeMode themeMode,  UiColorPalette colorPalette,  String? backgroundImage,  UiBackgroundFit backgroundFit,  double backgroundOverlay,  String? fontPath,  String? fontFamily,  UiColorThemeChoice colorTheme,  List<String> customColorThemePaths)?  $default,) {final _that = this;
switch (_that) {
case _UiAppearanceSettings() when $default != null:
return $default(_that.themeMode,_that.colorPalette,_that.backgroundImage,_that.backgroundFit,_that.backgroundOverlay,_that.fontPath,_that.fontFamily,_that.colorTheme,_that.customColorThemePaths);case _:
  return null;

}
}

}

/// @nodoc


class _UiAppearanceSettings implements UiAppearanceSettings {
  const _UiAppearanceSettings({required this.themeMode, required this.colorPalette, this.backgroundImage, required this.backgroundFit, required this.backgroundOverlay, this.fontPath, this.fontFamily, required this.colorTheme, required final  List<String> customColorThemePaths}): _customColorThemePaths = customColorThemePaths;
  

@override final  UiThemeMode themeMode;
@override final  UiColorPalette colorPalette;
@override final  String? backgroundImage;
@override final  UiBackgroundFit backgroundFit;
@override final  double backgroundOverlay;
@override final  String? fontPath;
@override final  String? fontFamily;
@override final  UiColorThemeChoice colorTheme;
 final  List<String> _customColorThemePaths;
@override List<String> get customColorThemePaths {
  if (_customColorThemePaths is EqualUnmodifiableListView) return _customColorThemePaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_customColorThemePaths);
}


/// Create a copy of UiAppearanceSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiAppearanceSettingsCopyWith<_UiAppearanceSettings> get copyWith => __$UiAppearanceSettingsCopyWithImpl<_UiAppearanceSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiAppearanceSettings&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.colorPalette, colorPalette) || other.colorPalette == colorPalette)&&(identical(other.backgroundImage, backgroundImage) || other.backgroundImage == backgroundImage)&&(identical(other.backgroundFit, backgroundFit) || other.backgroundFit == backgroundFit)&&(identical(other.backgroundOverlay, backgroundOverlay) || other.backgroundOverlay == backgroundOverlay)&&(identical(other.fontPath, fontPath) || other.fontPath == fontPath)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.colorTheme, colorTheme) || other.colorTheme == colorTheme)&&const DeepCollectionEquality().equals(other._customColorThemePaths, _customColorThemePaths));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,colorPalette,backgroundImage,backgroundFit,backgroundOverlay,fontPath,fontFamily,colorTheme,const DeepCollectionEquality().hash(_customColorThemePaths));

@override
String toString() {
  return 'UiAppearanceSettings(themeMode: $themeMode, colorPalette: $colorPalette, backgroundImage: $backgroundImage, backgroundFit: $backgroundFit, backgroundOverlay: $backgroundOverlay, fontPath: $fontPath, fontFamily: $fontFamily, colorTheme: $colorTheme, customColorThemePaths: $customColorThemePaths)';
}


}

/// @nodoc
abstract mixin class _$UiAppearanceSettingsCopyWith<$Res> implements $UiAppearanceSettingsCopyWith<$Res> {
  factory _$UiAppearanceSettingsCopyWith(_UiAppearanceSettings value, $Res Function(_UiAppearanceSettings) _then) = __$UiAppearanceSettingsCopyWithImpl;
@override @useResult
$Res call({
 UiThemeMode themeMode, UiColorPalette colorPalette, String? backgroundImage, UiBackgroundFit backgroundFit, double backgroundOverlay, String? fontPath, String? fontFamily, UiColorThemeChoice colorTheme, List<String> customColorThemePaths
});


@override $UiColorThemeChoiceCopyWith<$Res> get colorTheme;

}
/// @nodoc
class __$UiAppearanceSettingsCopyWithImpl<$Res>
    implements _$UiAppearanceSettingsCopyWith<$Res> {
  __$UiAppearanceSettingsCopyWithImpl(this._self, this._then);

  final _UiAppearanceSettings _self;
  final $Res Function(_UiAppearanceSettings) _then;

/// Create a copy of UiAppearanceSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? colorPalette = null,Object? backgroundImage = freezed,Object? backgroundFit = null,Object? backgroundOverlay = null,Object? fontPath = freezed,Object? fontFamily = freezed,Object? colorTheme = null,Object? customColorThemePaths = null,}) {
  return _then(_UiAppearanceSettings(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as UiThemeMode,colorPalette: null == colorPalette ? _self.colorPalette : colorPalette // ignore: cast_nullable_to_non_nullable
as UiColorPalette,backgroundImage: freezed == backgroundImage ? _self.backgroundImage : backgroundImage // ignore: cast_nullable_to_non_nullable
as String?,backgroundFit: null == backgroundFit ? _self.backgroundFit : backgroundFit // ignore: cast_nullable_to_non_nullable
as UiBackgroundFit,backgroundOverlay: null == backgroundOverlay ? _self.backgroundOverlay : backgroundOverlay // ignore: cast_nullable_to_non_nullable
as double,fontPath: freezed == fontPath ? _self.fontPath : fontPath // ignore: cast_nullable_to_non_nullable
as String?,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,colorTheme: null == colorTheme ? _self.colorTheme : colorTheme // ignore: cast_nullable_to_non_nullable
as UiColorThemeChoice,customColorThemePaths: null == customColorThemePaths ? _self._customColorThemePaths : customColorThemePaths // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of UiAppearanceSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiColorThemeChoiceCopyWith<$Res> get colorTheme {
  
  return $UiColorThemeChoiceCopyWith<$Res>(_self.colorTheme, (value) {
    return _then(_self.copyWith(colorTheme: value));
  });
}
}

/// @nodoc
mixin _$UiAudioPreferences {

 String? get outputHost; String? get outputDevice; bool get inputEnabled; String? get inputDevice; int get sampleRate; int get blockSize; String? get metronomeSound;
/// Create a copy of UiAudioPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiAudioPreferencesCopyWith<UiAudioPreferences> get copyWith => _$UiAudioPreferencesCopyWithImpl<UiAudioPreferences>(this as UiAudioPreferences, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiAudioPreferences&&(identical(other.outputHost, outputHost) || other.outputHost == outputHost)&&(identical(other.outputDevice, outputDevice) || other.outputDevice == outputDevice)&&(identical(other.inputEnabled, inputEnabled) || other.inputEnabled == inputEnabled)&&(identical(other.inputDevice, inputDevice) || other.inputDevice == inputDevice)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.blockSize, blockSize) || other.blockSize == blockSize)&&(identical(other.metronomeSound, metronomeSound) || other.metronomeSound == metronomeSound));
}


@override
int get hashCode => Object.hash(runtimeType,outputHost,outputDevice,inputEnabled,inputDevice,sampleRate,blockSize,metronomeSound);

@override
String toString() {
  return 'UiAudioPreferences(outputHost: $outputHost, outputDevice: $outputDevice, inputEnabled: $inputEnabled, inputDevice: $inputDevice, sampleRate: $sampleRate, blockSize: $blockSize, metronomeSound: $metronomeSound)';
}


}

/// @nodoc
abstract mixin class $UiAudioPreferencesCopyWith<$Res>  {
  factory $UiAudioPreferencesCopyWith(UiAudioPreferences value, $Res Function(UiAudioPreferences) _then) = _$UiAudioPreferencesCopyWithImpl;
@useResult
$Res call({
 String? outputHost, String? outputDevice, bool inputEnabled, String? inputDevice, int sampleRate, int blockSize, String? metronomeSound
});




}
/// @nodoc
class _$UiAudioPreferencesCopyWithImpl<$Res>
    implements $UiAudioPreferencesCopyWith<$Res> {
  _$UiAudioPreferencesCopyWithImpl(this._self, this._then);

  final UiAudioPreferences _self;
  final $Res Function(UiAudioPreferences) _then;

/// Create a copy of UiAudioPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outputHost = freezed,Object? outputDevice = freezed,Object? inputEnabled = null,Object? inputDevice = freezed,Object? sampleRate = null,Object? blockSize = null,Object? metronomeSound = freezed,}) {
  return _then(_self.copyWith(
outputHost: freezed == outputHost ? _self.outputHost : outputHost // ignore: cast_nullable_to_non_nullable
as String?,outputDevice: freezed == outputDevice ? _self.outputDevice : outputDevice // ignore: cast_nullable_to_non_nullable
as String?,inputEnabled: null == inputEnabled ? _self.inputEnabled : inputEnabled // ignore: cast_nullable_to_non_nullable
as bool,inputDevice: freezed == inputDevice ? _self.inputDevice : inputDevice // ignore: cast_nullable_to_non_nullable
as String?,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,blockSize: null == blockSize ? _self.blockSize : blockSize // ignore: cast_nullable_to_non_nullable
as int,metronomeSound: freezed == metronomeSound ? _self.metronomeSound : metronomeSound // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [UiAudioPreferences].
extension UiAudioPreferencesPatterns on UiAudioPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiAudioPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiAudioPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiAudioPreferences value)  $default,){
final _that = this;
switch (_that) {
case _UiAudioPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiAudioPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _UiAudioPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? outputHost,  String? outputDevice,  bool inputEnabled,  String? inputDevice,  int sampleRate,  int blockSize,  String? metronomeSound)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiAudioPreferences() when $default != null:
return $default(_that.outputHost,_that.outputDevice,_that.inputEnabled,_that.inputDevice,_that.sampleRate,_that.blockSize,_that.metronomeSound);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? outputHost,  String? outputDevice,  bool inputEnabled,  String? inputDevice,  int sampleRate,  int blockSize,  String? metronomeSound)  $default,) {final _that = this;
switch (_that) {
case _UiAudioPreferences():
return $default(_that.outputHost,_that.outputDevice,_that.inputEnabled,_that.inputDevice,_that.sampleRate,_that.blockSize,_that.metronomeSound);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? outputHost,  String? outputDevice,  bool inputEnabled,  String? inputDevice,  int sampleRate,  int blockSize,  String? metronomeSound)?  $default,) {final _that = this;
switch (_that) {
case _UiAudioPreferences() when $default != null:
return $default(_that.outputHost,_that.outputDevice,_that.inputEnabled,_that.inputDevice,_that.sampleRate,_that.blockSize,_that.metronomeSound);case _:
  return null;

}
}

}

/// @nodoc


class _UiAudioPreferences implements UiAudioPreferences {
  const _UiAudioPreferences({this.outputHost, this.outputDevice, required this.inputEnabled, this.inputDevice, required this.sampleRate, required this.blockSize, this.metronomeSound});
  

@override final  String? outputHost;
@override final  String? outputDevice;
@override final  bool inputEnabled;
@override final  String? inputDevice;
@override final  int sampleRate;
@override final  int blockSize;
@override final  String? metronomeSound;

/// Create a copy of UiAudioPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiAudioPreferencesCopyWith<_UiAudioPreferences> get copyWith => __$UiAudioPreferencesCopyWithImpl<_UiAudioPreferences>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiAudioPreferences&&(identical(other.outputHost, outputHost) || other.outputHost == outputHost)&&(identical(other.outputDevice, outputDevice) || other.outputDevice == outputDevice)&&(identical(other.inputEnabled, inputEnabled) || other.inputEnabled == inputEnabled)&&(identical(other.inputDevice, inputDevice) || other.inputDevice == inputDevice)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.blockSize, blockSize) || other.blockSize == blockSize)&&(identical(other.metronomeSound, metronomeSound) || other.metronomeSound == metronomeSound));
}


@override
int get hashCode => Object.hash(runtimeType,outputHost,outputDevice,inputEnabled,inputDevice,sampleRate,blockSize,metronomeSound);

@override
String toString() {
  return 'UiAudioPreferences(outputHost: $outputHost, outputDevice: $outputDevice, inputEnabled: $inputEnabled, inputDevice: $inputDevice, sampleRate: $sampleRate, blockSize: $blockSize, metronomeSound: $metronomeSound)';
}


}

/// @nodoc
abstract mixin class _$UiAudioPreferencesCopyWith<$Res> implements $UiAudioPreferencesCopyWith<$Res> {
  factory _$UiAudioPreferencesCopyWith(_UiAudioPreferences value, $Res Function(_UiAudioPreferences) _then) = __$UiAudioPreferencesCopyWithImpl;
@override @useResult
$Res call({
 String? outputHost, String? outputDevice, bool inputEnabled, String? inputDevice, int sampleRate, int blockSize, String? metronomeSound
});




}
/// @nodoc
class __$UiAudioPreferencesCopyWithImpl<$Res>
    implements _$UiAudioPreferencesCopyWith<$Res> {
  __$UiAudioPreferencesCopyWithImpl(this._self, this._then);

  final _UiAudioPreferences _self;
  final $Res Function(_UiAudioPreferences) _then;

/// Create a copy of UiAudioPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outputHost = freezed,Object? outputDevice = freezed,Object? inputEnabled = null,Object? inputDevice = freezed,Object? sampleRate = null,Object? blockSize = null,Object? metronomeSound = freezed,}) {
  return _then(_UiAudioPreferences(
outputHost: freezed == outputHost ? _self.outputHost : outputHost // ignore: cast_nullable_to_non_nullable
as String?,outputDevice: freezed == outputDevice ? _self.outputDevice : outputDevice // ignore: cast_nullable_to_non_nullable
as String?,inputEnabled: null == inputEnabled ? _self.inputEnabled : inputEnabled // ignore: cast_nullable_to_non_nullable
as bool,inputDevice: freezed == inputDevice ? _self.inputDevice : inputDevice // ignore: cast_nullable_to_non_nullable
as String?,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,blockSize: null == blockSize ? _self.blockSize : blockSize // ignore: cast_nullable_to_non_nullable
as int,metronomeSound: freezed == metronomeSound ? _self.metronomeSound : metronomeSound // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$UiColorThemeChoice {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiColorThemeChoice);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiColorThemeChoice()';
}


}

/// @nodoc
class $UiColorThemeChoiceCopyWith<$Res>  {
$UiColorThemeChoiceCopyWith(UiColorThemeChoice _, $Res Function(UiColorThemeChoice) __);
}


/// Adds pattern-matching-related methods to [UiColorThemeChoice].
extension UiColorThemeChoicePatterns on UiColorThemeChoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiColorThemeChoice_Bundled value)?  bundled,TResult Function( UiColorThemeChoice_AccentPalette value)?  accentPalette,TResult Function( UiColorThemeChoice_Source value)?  source,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiColorThemeChoice_Bundled() when bundled != null:
return bundled(_that);case UiColorThemeChoice_AccentPalette() when accentPalette != null:
return accentPalette(_that);case UiColorThemeChoice_Source() when source != null:
return source(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiColorThemeChoice_Bundled value)  bundled,required TResult Function( UiColorThemeChoice_AccentPalette value)  accentPalette,required TResult Function( UiColorThemeChoice_Source value)  source,}){
final _that = this;
switch (_that) {
case UiColorThemeChoice_Bundled():
return bundled(_that);case UiColorThemeChoice_AccentPalette():
return accentPalette(_that);case UiColorThemeChoice_Source():
return source(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiColorThemeChoice_Bundled value)?  bundled,TResult? Function( UiColorThemeChoice_AccentPalette value)?  accentPalette,TResult? Function( UiColorThemeChoice_Source value)?  source,}){
final _that = this;
switch (_that) {
case UiColorThemeChoice_Bundled() when bundled != null:
return bundled(_that);case UiColorThemeChoice_AccentPalette() when accentPalette != null:
return accentPalette(_that);case UiColorThemeChoice_Source() when source != null:
return source(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  bundled,TResult Function()?  accentPalette,TResult Function( String field0)?  source,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiColorThemeChoice_Bundled() when bundled != null:
return bundled();case UiColorThemeChoice_AccentPalette() when accentPalette != null:
return accentPalette();case UiColorThemeChoice_Source() when source != null:
return source(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  bundled,required TResult Function()  accentPalette,required TResult Function( String field0)  source,}) {final _that = this;
switch (_that) {
case UiColorThemeChoice_Bundled():
return bundled();case UiColorThemeChoice_AccentPalette():
return accentPalette();case UiColorThemeChoice_Source():
return source(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  bundled,TResult? Function()?  accentPalette,TResult? Function( String field0)?  source,}) {final _that = this;
switch (_that) {
case UiColorThemeChoice_Bundled() when bundled != null:
return bundled();case UiColorThemeChoice_AccentPalette() when accentPalette != null:
return accentPalette();case UiColorThemeChoice_Source() when source != null:
return source(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class UiColorThemeChoice_Bundled extends UiColorThemeChoice {
  const UiColorThemeChoice_Bundled(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiColorThemeChoice_Bundled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiColorThemeChoice.bundled()';
}


}




/// @nodoc


class UiColorThemeChoice_AccentPalette extends UiColorThemeChoice {
  const UiColorThemeChoice_AccentPalette(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiColorThemeChoice_AccentPalette);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiColorThemeChoice.accentPalette()';
}


}




/// @nodoc


class UiColorThemeChoice_Source extends UiColorThemeChoice {
  const UiColorThemeChoice_Source(this.field0): super._();
  

 final  String field0;

/// Create a copy of UiColorThemeChoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiColorThemeChoice_SourceCopyWith<UiColorThemeChoice_Source> get copyWith => _$UiColorThemeChoice_SourceCopyWithImpl<UiColorThemeChoice_Source>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiColorThemeChoice_Source&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiColorThemeChoice.source(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiColorThemeChoice_SourceCopyWith<$Res> implements $UiColorThemeChoiceCopyWith<$Res> {
  factory $UiColorThemeChoice_SourceCopyWith(UiColorThemeChoice_Source value, $Res Function(UiColorThemeChoice_Source) _then) = _$UiColorThemeChoice_SourceCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$UiColorThemeChoice_SourceCopyWithImpl<$Res>
    implements $UiColorThemeChoice_SourceCopyWith<$Res> {
  _$UiColorThemeChoice_SourceCopyWithImpl(this._self, this._then);

  final UiColorThemeChoice_Source _self;
  final $Res Function(UiColorThemeChoice_Source) _then;

/// Create a copy of UiColorThemeChoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiColorThemeChoice_Source(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiGeneralSettings {

 int get historyLimit; UiAutoSaveSettings get autoSave; String? get defaultProjectFolder; String? get defaultExportFolder; bool get showRecentProjects;
/// Create a copy of UiGeneralSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiGeneralSettingsCopyWith<UiGeneralSettings> get copyWith => _$UiGeneralSettingsCopyWithImpl<UiGeneralSettings>(this as UiGeneralSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiGeneralSettings&&(identical(other.historyLimit, historyLimit) || other.historyLimit == historyLimit)&&(identical(other.autoSave, autoSave) || other.autoSave == autoSave)&&(identical(other.defaultProjectFolder, defaultProjectFolder) || other.defaultProjectFolder == defaultProjectFolder)&&(identical(other.defaultExportFolder, defaultExportFolder) || other.defaultExportFolder == defaultExportFolder)&&(identical(other.showRecentProjects, showRecentProjects) || other.showRecentProjects == showRecentProjects));
}


@override
int get hashCode => Object.hash(runtimeType,historyLimit,autoSave,defaultProjectFolder,defaultExportFolder,showRecentProjects);

@override
String toString() {
  return 'UiGeneralSettings(historyLimit: $historyLimit, autoSave: $autoSave, defaultProjectFolder: $defaultProjectFolder, defaultExportFolder: $defaultExportFolder, showRecentProjects: $showRecentProjects)';
}


}

/// @nodoc
abstract mixin class $UiGeneralSettingsCopyWith<$Res>  {
  factory $UiGeneralSettingsCopyWith(UiGeneralSettings value, $Res Function(UiGeneralSettings) _then) = _$UiGeneralSettingsCopyWithImpl;
@useResult
$Res call({
 int historyLimit, UiAutoSaveSettings autoSave, String? defaultProjectFolder, String? defaultExportFolder, bool showRecentProjects
});


$UiAutoSaveSettingsCopyWith<$Res> get autoSave;

}
/// @nodoc
class _$UiGeneralSettingsCopyWithImpl<$Res>
    implements $UiGeneralSettingsCopyWith<$Res> {
  _$UiGeneralSettingsCopyWithImpl(this._self, this._then);

  final UiGeneralSettings _self;
  final $Res Function(UiGeneralSettings) _then;

/// Create a copy of UiGeneralSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? historyLimit = null,Object? autoSave = null,Object? defaultProjectFolder = freezed,Object? defaultExportFolder = freezed,Object? showRecentProjects = null,}) {
  return _then(_self.copyWith(
historyLimit: null == historyLimit ? _self.historyLimit : historyLimit // ignore: cast_nullable_to_non_nullable
as int,autoSave: null == autoSave ? _self.autoSave : autoSave // ignore: cast_nullable_to_non_nullable
as UiAutoSaveSettings,defaultProjectFolder: freezed == defaultProjectFolder ? _self.defaultProjectFolder : defaultProjectFolder // ignore: cast_nullable_to_non_nullable
as String?,defaultExportFolder: freezed == defaultExportFolder ? _self.defaultExportFolder : defaultExportFolder // ignore: cast_nullable_to_non_nullable
as String?,showRecentProjects: null == showRecentProjects ? _self.showRecentProjects : showRecentProjects // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of UiGeneralSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiAutoSaveSettingsCopyWith<$Res> get autoSave {
  
  return $UiAutoSaveSettingsCopyWith<$Res>(_self.autoSave, (value) {
    return _then(_self.copyWith(autoSave: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiGeneralSettings].
extension UiGeneralSettingsPatterns on UiGeneralSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiGeneralSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiGeneralSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiGeneralSettings value)  $default,){
final _that = this;
switch (_that) {
case _UiGeneralSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiGeneralSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UiGeneralSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int historyLimit,  UiAutoSaveSettings autoSave,  String? defaultProjectFolder,  String? defaultExportFolder,  bool showRecentProjects)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiGeneralSettings() when $default != null:
return $default(_that.historyLimit,_that.autoSave,_that.defaultProjectFolder,_that.defaultExportFolder,_that.showRecentProjects);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int historyLimit,  UiAutoSaveSettings autoSave,  String? defaultProjectFolder,  String? defaultExportFolder,  bool showRecentProjects)  $default,) {final _that = this;
switch (_that) {
case _UiGeneralSettings():
return $default(_that.historyLimit,_that.autoSave,_that.defaultProjectFolder,_that.defaultExportFolder,_that.showRecentProjects);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int historyLimit,  UiAutoSaveSettings autoSave,  String? defaultProjectFolder,  String? defaultExportFolder,  bool showRecentProjects)?  $default,) {final _that = this;
switch (_that) {
case _UiGeneralSettings() when $default != null:
return $default(_that.historyLimit,_that.autoSave,_that.defaultProjectFolder,_that.defaultExportFolder,_that.showRecentProjects);case _:
  return null;

}
}

}

/// @nodoc


class _UiGeneralSettings implements UiGeneralSettings {
  const _UiGeneralSettings({required this.historyLimit, required this.autoSave, this.defaultProjectFolder, this.defaultExportFolder, required this.showRecentProjects});
  

@override final  int historyLimit;
@override final  UiAutoSaveSettings autoSave;
@override final  String? defaultProjectFolder;
@override final  String? defaultExportFolder;
@override final  bool showRecentProjects;

/// Create a copy of UiGeneralSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiGeneralSettingsCopyWith<_UiGeneralSettings> get copyWith => __$UiGeneralSettingsCopyWithImpl<_UiGeneralSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiGeneralSettings&&(identical(other.historyLimit, historyLimit) || other.historyLimit == historyLimit)&&(identical(other.autoSave, autoSave) || other.autoSave == autoSave)&&(identical(other.defaultProjectFolder, defaultProjectFolder) || other.defaultProjectFolder == defaultProjectFolder)&&(identical(other.defaultExportFolder, defaultExportFolder) || other.defaultExportFolder == defaultExportFolder)&&(identical(other.showRecentProjects, showRecentProjects) || other.showRecentProjects == showRecentProjects));
}


@override
int get hashCode => Object.hash(runtimeType,historyLimit,autoSave,defaultProjectFolder,defaultExportFolder,showRecentProjects);

@override
String toString() {
  return 'UiGeneralSettings(historyLimit: $historyLimit, autoSave: $autoSave, defaultProjectFolder: $defaultProjectFolder, defaultExportFolder: $defaultExportFolder, showRecentProjects: $showRecentProjects)';
}


}

/// @nodoc
abstract mixin class _$UiGeneralSettingsCopyWith<$Res> implements $UiGeneralSettingsCopyWith<$Res> {
  factory _$UiGeneralSettingsCopyWith(_UiGeneralSettings value, $Res Function(_UiGeneralSettings) _then) = __$UiGeneralSettingsCopyWithImpl;
@override @useResult
$Res call({
 int historyLimit, UiAutoSaveSettings autoSave, String? defaultProjectFolder, String? defaultExportFolder, bool showRecentProjects
});


@override $UiAutoSaveSettingsCopyWith<$Res> get autoSave;

}
/// @nodoc
class __$UiGeneralSettingsCopyWithImpl<$Res>
    implements _$UiGeneralSettingsCopyWith<$Res> {
  __$UiGeneralSettingsCopyWithImpl(this._self, this._then);

  final _UiGeneralSettings _self;
  final $Res Function(_UiGeneralSettings) _then;

/// Create a copy of UiGeneralSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? historyLimit = null,Object? autoSave = null,Object? defaultProjectFolder = freezed,Object? defaultExportFolder = freezed,Object? showRecentProjects = null,}) {
  return _then(_UiGeneralSettings(
historyLimit: null == historyLimit ? _self.historyLimit : historyLimit // ignore: cast_nullable_to_non_nullable
as int,autoSave: null == autoSave ? _self.autoSave : autoSave // ignore: cast_nullable_to_non_nullable
as UiAutoSaveSettings,defaultProjectFolder: freezed == defaultProjectFolder ? _self.defaultProjectFolder : defaultProjectFolder // ignore: cast_nullable_to_non_nullable
as String?,defaultExportFolder: freezed == defaultExportFolder ? _self.defaultExportFolder : defaultExportFolder // ignore: cast_nullable_to_non_nullable
as String?,showRecentProjects: null == showRecentProjects ? _self.showRecentProjects : showRecentProjects // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of UiGeneralSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiAutoSaveSettingsCopyWith<$Res> get autoSave {
  
  return $UiAutoSaveSettingsCopyWith<$Res>(_self.autoSave, (value) {
    return _then(_self.copyWith(autoSave: value));
  });
}
}

/// @nodoc
mixin _$UiLogSettings {

 UiLogLevel get minimumLevel; int get maximumEntries;
/// Create a copy of UiLogSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiLogSettingsCopyWith<UiLogSettings> get copyWith => _$UiLogSettingsCopyWithImpl<UiLogSettings>(this as UiLogSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiLogSettings&&(identical(other.minimumLevel, minimumLevel) || other.minimumLevel == minimumLevel)&&(identical(other.maximumEntries, maximumEntries) || other.maximumEntries == maximumEntries));
}


@override
int get hashCode => Object.hash(runtimeType,minimumLevel,maximumEntries);

@override
String toString() {
  return 'UiLogSettings(minimumLevel: $minimumLevel, maximumEntries: $maximumEntries)';
}


}

/// @nodoc
abstract mixin class $UiLogSettingsCopyWith<$Res>  {
  factory $UiLogSettingsCopyWith(UiLogSettings value, $Res Function(UiLogSettings) _then) = _$UiLogSettingsCopyWithImpl;
@useResult
$Res call({
 UiLogLevel minimumLevel, int maximumEntries
});




}
/// @nodoc
class _$UiLogSettingsCopyWithImpl<$Res>
    implements $UiLogSettingsCopyWith<$Res> {
  _$UiLogSettingsCopyWithImpl(this._self, this._then);

  final UiLogSettings _self;
  final $Res Function(UiLogSettings) _then;

/// Create a copy of UiLogSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minimumLevel = null,Object? maximumEntries = null,}) {
  return _then(_self.copyWith(
minimumLevel: null == minimumLevel ? _self.minimumLevel : minimumLevel // ignore: cast_nullable_to_non_nullable
as UiLogLevel,maximumEntries: null == maximumEntries ? _self.maximumEntries : maximumEntries // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiLogSettings].
extension UiLogSettingsPatterns on UiLogSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiLogSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiLogSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiLogSettings value)  $default,){
final _that = this;
switch (_that) {
case _UiLogSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiLogSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UiLogSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiLogLevel minimumLevel,  int maximumEntries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiLogSettings() when $default != null:
return $default(_that.minimumLevel,_that.maximumEntries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiLogLevel minimumLevel,  int maximumEntries)  $default,) {final _that = this;
switch (_that) {
case _UiLogSettings():
return $default(_that.minimumLevel,_that.maximumEntries);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiLogLevel minimumLevel,  int maximumEntries)?  $default,) {final _that = this;
switch (_that) {
case _UiLogSettings() when $default != null:
return $default(_that.minimumLevel,_that.maximumEntries);case _:
  return null;

}
}

}

/// @nodoc


class _UiLogSettings implements UiLogSettings {
  const _UiLogSettings({required this.minimumLevel, required this.maximumEntries});
  

@override final  UiLogLevel minimumLevel;
@override final  int maximumEntries;

/// Create a copy of UiLogSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiLogSettingsCopyWith<_UiLogSettings> get copyWith => __$UiLogSettingsCopyWithImpl<_UiLogSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiLogSettings&&(identical(other.minimumLevel, minimumLevel) || other.minimumLevel == minimumLevel)&&(identical(other.maximumEntries, maximumEntries) || other.maximumEntries == maximumEntries));
}


@override
int get hashCode => Object.hash(runtimeType,minimumLevel,maximumEntries);

@override
String toString() {
  return 'UiLogSettings(minimumLevel: $minimumLevel, maximumEntries: $maximumEntries)';
}


}

/// @nodoc
abstract mixin class _$UiLogSettingsCopyWith<$Res> implements $UiLogSettingsCopyWith<$Res> {
  factory _$UiLogSettingsCopyWith(_UiLogSettings value, $Res Function(_UiLogSettings) _then) = __$UiLogSettingsCopyWithImpl;
@override @useResult
$Res call({
 UiLogLevel minimumLevel, int maximumEntries
});




}
/// @nodoc
class __$UiLogSettingsCopyWithImpl<$Res>
    implements _$UiLogSettingsCopyWith<$Res> {
  __$UiLogSettingsCopyWithImpl(this._self, this._then);

  final _UiLogSettings _self;
  final $Res Function(_UiLogSettings) _then;

/// Create a copy of UiLogSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minimumLevel = null,Object? maximumEntries = null,}) {
  return _then(_UiLogSettings(
minimumLevel: null == minimumLevel ? _self.minimumLevel : minimumLevel // ignore: cast_nullable_to_non_nullable
as UiLogLevel,maximumEntries: null == maximumEntries ? _self.maximumEntries : maximumEntries // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
