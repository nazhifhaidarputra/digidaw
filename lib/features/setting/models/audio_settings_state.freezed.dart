// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioSettingsState {

 IList<int> get supportedSampleRates; IList<int> get supportedBlockSizes; int get appliedSampleRate; int get appliedBlockSize; int get draftSampleRate; int get draftBlockSize; bool get isApplying; bool get isInitialized; String? get fallbackReason; UiAudioRuntimeSettings? get runtimeSettings;
/// Create a copy of AudioSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioSettingsStateCopyWith<AudioSettingsState> get copyWith => _$AudioSettingsStateCopyWithImpl<AudioSettingsState>(this as AudioSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioSettingsState&&const DeepCollectionEquality().equals(other.supportedSampleRates, supportedSampleRates)&&const DeepCollectionEquality().equals(other.supportedBlockSizes, supportedBlockSizes)&&(identical(other.appliedSampleRate, appliedSampleRate) || other.appliedSampleRate == appliedSampleRate)&&(identical(other.appliedBlockSize, appliedBlockSize) || other.appliedBlockSize == appliedBlockSize)&&(identical(other.draftSampleRate, draftSampleRate) || other.draftSampleRate == draftSampleRate)&&(identical(other.draftBlockSize, draftBlockSize) || other.draftBlockSize == draftBlockSize)&&(identical(other.isApplying, isApplying) || other.isApplying == isApplying)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.fallbackReason, fallbackReason) || other.fallbackReason == fallbackReason)&&(identical(other.runtimeSettings, runtimeSettings) || other.runtimeSettings == runtimeSettings));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(supportedSampleRates),const DeepCollectionEquality().hash(supportedBlockSizes),appliedSampleRate,appliedBlockSize,draftSampleRate,draftBlockSize,isApplying,isInitialized,fallbackReason,runtimeSettings);

@override
String toString() {
  return 'AudioSettingsState(supportedSampleRates: $supportedSampleRates, supportedBlockSizes: $supportedBlockSizes, appliedSampleRate: $appliedSampleRate, appliedBlockSize: $appliedBlockSize, draftSampleRate: $draftSampleRate, draftBlockSize: $draftBlockSize, isApplying: $isApplying, isInitialized: $isInitialized, fallbackReason: $fallbackReason, runtimeSettings: $runtimeSettings)';
}


}

/// @nodoc
abstract mixin class $AudioSettingsStateCopyWith<$Res>  {
  factory $AudioSettingsStateCopyWith(AudioSettingsState value, $Res Function(AudioSettingsState) _then) = _$AudioSettingsStateCopyWithImpl;
@useResult
$Res call({
 IList<int> supportedSampleRates, IList<int> supportedBlockSizes, int appliedSampleRate, int appliedBlockSize, int draftSampleRate, int draftBlockSize, bool isApplying, bool isInitialized, String? fallbackReason, UiAudioRuntimeSettings? runtimeSettings
});


$UiAudioRuntimeSettingsCopyWith<$Res>? get runtimeSettings;

}
/// @nodoc
class _$AudioSettingsStateCopyWithImpl<$Res>
    implements $AudioSettingsStateCopyWith<$Res> {
  _$AudioSettingsStateCopyWithImpl(this._self, this._then);

  final AudioSettingsState _self;
  final $Res Function(AudioSettingsState) _then;

/// Create a copy of AudioSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? supportedSampleRates = null,Object? supportedBlockSizes = null,Object? appliedSampleRate = null,Object? appliedBlockSize = null,Object? draftSampleRate = null,Object? draftBlockSize = null,Object? isApplying = null,Object? isInitialized = null,Object? fallbackReason = freezed,Object? runtimeSettings = freezed,}) {
  return _then(_self.copyWith(
supportedSampleRates: null == supportedSampleRates ? _self.supportedSampleRates : supportedSampleRates // ignore: cast_nullable_to_non_nullable
as IList<int>,supportedBlockSizes: null == supportedBlockSizes ? _self.supportedBlockSizes : supportedBlockSizes // ignore: cast_nullable_to_non_nullable
as IList<int>,appliedSampleRate: null == appliedSampleRate ? _self.appliedSampleRate : appliedSampleRate // ignore: cast_nullable_to_non_nullable
as int,appliedBlockSize: null == appliedBlockSize ? _self.appliedBlockSize : appliedBlockSize // ignore: cast_nullable_to_non_nullable
as int,draftSampleRate: null == draftSampleRate ? _self.draftSampleRate : draftSampleRate // ignore: cast_nullable_to_non_nullable
as int,draftBlockSize: null == draftBlockSize ? _self.draftBlockSize : draftBlockSize // ignore: cast_nullable_to_non_nullable
as int,isApplying: null == isApplying ? _self.isApplying : isApplying // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,fallbackReason: freezed == fallbackReason ? _self.fallbackReason : fallbackReason // ignore: cast_nullable_to_non_nullable
as String?,runtimeSettings: freezed == runtimeSettings ? _self.runtimeSettings : runtimeSettings // ignore: cast_nullable_to_non_nullable
as UiAudioRuntimeSettings?,
  ));
}
/// Create a copy of AudioSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiAudioRuntimeSettingsCopyWith<$Res>? get runtimeSettings {
    if (_self.runtimeSettings == null) {
    return null;
  }

  return $UiAudioRuntimeSettingsCopyWith<$Res>(_self.runtimeSettings!, (value) {
    return _then(_self.copyWith(runtimeSettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [AudioSettingsState].
extension AudioSettingsStatePatterns on AudioSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _AudioSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _AudioSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IList<int> supportedSampleRates,  IList<int> supportedBlockSizes,  int appliedSampleRate,  int appliedBlockSize,  int draftSampleRate,  int draftBlockSize,  bool isApplying,  bool isInitialized,  String? fallbackReason,  UiAudioRuntimeSettings? runtimeSettings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioSettingsState() when $default != null:
return $default(_that.supportedSampleRates,_that.supportedBlockSizes,_that.appliedSampleRate,_that.appliedBlockSize,_that.draftSampleRate,_that.draftBlockSize,_that.isApplying,_that.isInitialized,_that.fallbackReason,_that.runtimeSettings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IList<int> supportedSampleRates,  IList<int> supportedBlockSizes,  int appliedSampleRate,  int appliedBlockSize,  int draftSampleRate,  int draftBlockSize,  bool isApplying,  bool isInitialized,  String? fallbackReason,  UiAudioRuntimeSettings? runtimeSettings)  $default,) {final _that = this;
switch (_that) {
case _AudioSettingsState():
return $default(_that.supportedSampleRates,_that.supportedBlockSizes,_that.appliedSampleRate,_that.appliedBlockSize,_that.draftSampleRate,_that.draftBlockSize,_that.isApplying,_that.isInitialized,_that.fallbackReason,_that.runtimeSettings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IList<int> supportedSampleRates,  IList<int> supportedBlockSizes,  int appliedSampleRate,  int appliedBlockSize,  int draftSampleRate,  int draftBlockSize,  bool isApplying,  bool isInitialized,  String? fallbackReason,  UiAudioRuntimeSettings? runtimeSettings)?  $default,) {final _that = this;
switch (_that) {
case _AudioSettingsState() when $default != null:
return $default(_that.supportedSampleRates,_that.supportedBlockSizes,_that.appliedSampleRate,_that.appliedBlockSize,_that.draftSampleRate,_that.draftBlockSize,_that.isApplying,_that.isInitialized,_that.fallbackReason,_that.runtimeSettings);case _:
  return null;

}
}

}

/// @nodoc


class _AudioSettingsState extends AudioSettingsState {
  const _AudioSettingsState({this.supportedSampleRates = const IListConst<int>([44100, 48000, 88200, 96000]), this.supportedBlockSizes = const IListConst<int>([64, 128, 256, 512, 1024, 2048]), this.appliedSampleRate = 48000, this.appliedBlockSize = 1024, this.draftSampleRate = 48000, this.draftBlockSize = 1024, this.isApplying = false, this.isInitialized = false, this.fallbackReason, this.runtimeSettings}): super._();
  

@override@JsonKey() final  IList<int> supportedSampleRates;
@override@JsonKey() final  IList<int> supportedBlockSizes;
@override@JsonKey() final  int appliedSampleRate;
@override@JsonKey() final  int appliedBlockSize;
@override@JsonKey() final  int draftSampleRate;
@override@JsonKey() final  int draftBlockSize;
@override@JsonKey() final  bool isApplying;
@override@JsonKey() final  bool isInitialized;
@override final  String? fallbackReason;
@override final  UiAudioRuntimeSettings? runtimeSettings;

/// Create a copy of AudioSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioSettingsStateCopyWith<_AudioSettingsState> get copyWith => __$AudioSettingsStateCopyWithImpl<_AudioSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioSettingsState&&const DeepCollectionEquality().equals(other.supportedSampleRates, supportedSampleRates)&&const DeepCollectionEquality().equals(other.supportedBlockSizes, supportedBlockSizes)&&(identical(other.appliedSampleRate, appliedSampleRate) || other.appliedSampleRate == appliedSampleRate)&&(identical(other.appliedBlockSize, appliedBlockSize) || other.appliedBlockSize == appliedBlockSize)&&(identical(other.draftSampleRate, draftSampleRate) || other.draftSampleRate == draftSampleRate)&&(identical(other.draftBlockSize, draftBlockSize) || other.draftBlockSize == draftBlockSize)&&(identical(other.isApplying, isApplying) || other.isApplying == isApplying)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.fallbackReason, fallbackReason) || other.fallbackReason == fallbackReason)&&(identical(other.runtimeSettings, runtimeSettings) || other.runtimeSettings == runtimeSettings));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(supportedSampleRates),const DeepCollectionEquality().hash(supportedBlockSizes),appliedSampleRate,appliedBlockSize,draftSampleRate,draftBlockSize,isApplying,isInitialized,fallbackReason,runtimeSettings);

@override
String toString() {
  return 'AudioSettingsState(supportedSampleRates: $supportedSampleRates, supportedBlockSizes: $supportedBlockSizes, appliedSampleRate: $appliedSampleRate, appliedBlockSize: $appliedBlockSize, draftSampleRate: $draftSampleRate, draftBlockSize: $draftBlockSize, isApplying: $isApplying, isInitialized: $isInitialized, fallbackReason: $fallbackReason, runtimeSettings: $runtimeSettings)';
}


}

/// @nodoc
abstract mixin class _$AudioSettingsStateCopyWith<$Res> implements $AudioSettingsStateCopyWith<$Res> {
  factory _$AudioSettingsStateCopyWith(_AudioSettingsState value, $Res Function(_AudioSettingsState) _then) = __$AudioSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 IList<int> supportedSampleRates, IList<int> supportedBlockSizes, int appliedSampleRate, int appliedBlockSize, int draftSampleRate, int draftBlockSize, bool isApplying, bool isInitialized, String? fallbackReason, UiAudioRuntimeSettings? runtimeSettings
});


@override $UiAudioRuntimeSettingsCopyWith<$Res>? get runtimeSettings;

}
/// @nodoc
class __$AudioSettingsStateCopyWithImpl<$Res>
    implements _$AudioSettingsStateCopyWith<$Res> {
  __$AudioSettingsStateCopyWithImpl(this._self, this._then);

  final _AudioSettingsState _self;
  final $Res Function(_AudioSettingsState) _then;

/// Create a copy of AudioSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? supportedSampleRates = null,Object? supportedBlockSizes = null,Object? appliedSampleRate = null,Object? appliedBlockSize = null,Object? draftSampleRate = null,Object? draftBlockSize = null,Object? isApplying = null,Object? isInitialized = null,Object? fallbackReason = freezed,Object? runtimeSettings = freezed,}) {
  return _then(_AudioSettingsState(
supportedSampleRates: null == supportedSampleRates ? _self.supportedSampleRates : supportedSampleRates // ignore: cast_nullable_to_non_nullable
as IList<int>,supportedBlockSizes: null == supportedBlockSizes ? _self.supportedBlockSizes : supportedBlockSizes // ignore: cast_nullable_to_non_nullable
as IList<int>,appliedSampleRate: null == appliedSampleRate ? _self.appliedSampleRate : appliedSampleRate // ignore: cast_nullable_to_non_nullable
as int,appliedBlockSize: null == appliedBlockSize ? _self.appliedBlockSize : appliedBlockSize // ignore: cast_nullable_to_non_nullable
as int,draftSampleRate: null == draftSampleRate ? _self.draftSampleRate : draftSampleRate // ignore: cast_nullable_to_non_nullable
as int,draftBlockSize: null == draftBlockSize ? _self.draftBlockSize : draftBlockSize // ignore: cast_nullable_to_non_nullable
as int,isApplying: null == isApplying ? _self.isApplying : isApplying // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,fallbackReason: freezed == fallbackReason ? _self.fallbackReason : fallbackReason // ignore: cast_nullable_to_non_nullable
as String?,runtimeSettings: freezed == runtimeSettings ? _self.runtimeSettings : runtimeSettings // ignore: cast_nullable_to_non_nullable
as UiAudioRuntimeSettings?,
  ));
}

/// Create a copy of AudioSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiAudioRuntimeSettingsCopyWith<$Res>? get runtimeSettings {
    if (_self.runtimeSettings == null) {
    return null;
  }

  return $UiAudioRuntimeSettingsCopyWith<$Res>(_self.runtimeSettings!, (value) {
    return _then(_self.copyWith(runtimeSettings: value));
  });
}
}

// dart format on
