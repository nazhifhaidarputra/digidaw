// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiActualDeviceStreamConfig {

 String get hostName; String get deviceId; String get deviceName; int get sampleRate; int get callbackBufferSize; int get channels;
/// Create a copy of UiActualDeviceStreamConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiActualDeviceStreamConfigCopyWith<UiActualDeviceStreamConfig> get copyWith => _$UiActualDeviceStreamConfigCopyWithImpl<UiActualDeviceStreamConfig>(this as UiActualDeviceStreamConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiActualDeviceStreamConfig&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.callbackBufferSize, callbackBufferSize) || other.callbackBufferSize == callbackBufferSize)&&(identical(other.channels, channels) || other.channels == channels));
}


@override
int get hashCode => Object.hash(runtimeType,hostName,deviceId,deviceName,sampleRate,callbackBufferSize,channels);

@override
String toString() {
  return 'UiActualDeviceStreamConfig(hostName: $hostName, deviceId: $deviceId, deviceName: $deviceName, sampleRate: $sampleRate, callbackBufferSize: $callbackBufferSize, channels: $channels)';
}


}

/// @nodoc
abstract mixin class $UiActualDeviceStreamConfigCopyWith<$Res>  {
  factory $UiActualDeviceStreamConfigCopyWith(UiActualDeviceStreamConfig value, $Res Function(UiActualDeviceStreamConfig) _then) = _$UiActualDeviceStreamConfigCopyWithImpl;
@useResult
$Res call({
 String hostName, String deviceId, String deviceName, int sampleRate, int callbackBufferSize, int channels
});




}
/// @nodoc
class _$UiActualDeviceStreamConfigCopyWithImpl<$Res>
    implements $UiActualDeviceStreamConfigCopyWith<$Res> {
  _$UiActualDeviceStreamConfigCopyWithImpl(this._self, this._then);

  final UiActualDeviceStreamConfig _self;
  final $Res Function(UiActualDeviceStreamConfig) _then;

/// Create a copy of UiActualDeviceStreamConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostName = null,Object? deviceId = null,Object? deviceName = null,Object? sampleRate = null,Object? callbackBufferSize = null,Object? channels = null,}) {
  return _then(_self.copyWith(
hostName: null == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,deviceName: null == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,callbackBufferSize: null == callbackBufferSize ? _self.callbackBufferSize : callbackBufferSize // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiActualDeviceStreamConfig].
extension UiActualDeviceStreamConfigPatterns on UiActualDeviceStreamConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiActualDeviceStreamConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiActualDeviceStreamConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiActualDeviceStreamConfig value)  $default,){
final _that = this;
switch (_that) {
case _UiActualDeviceStreamConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiActualDeviceStreamConfig value)?  $default,){
final _that = this;
switch (_that) {
case _UiActualDeviceStreamConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String hostName,  String deviceId,  String deviceName,  int sampleRate,  int callbackBufferSize,  int channels)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiActualDeviceStreamConfig() when $default != null:
return $default(_that.hostName,_that.deviceId,_that.deviceName,_that.sampleRate,_that.callbackBufferSize,_that.channels);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String hostName,  String deviceId,  String deviceName,  int sampleRate,  int callbackBufferSize,  int channels)  $default,) {final _that = this;
switch (_that) {
case _UiActualDeviceStreamConfig():
return $default(_that.hostName,_that.deviceId,_that.deviceName,_that.sampleRate,_that.callbackBufferSize,_that.channels);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String hostName,  String deviceId,  String deviceName,  int sampleRate,  int callbackBufferSize,  int channels)?  $default,) {final _that = this;
switch (_that) {
case _UiActualDeviceStreamConfig() when $default != null:
return $default(_that.hostName,_that.deviceId,_that.deviceName,_that.sampleRate,_that.callbackBufferSize,_that.channels);case _:
  return null;

}
}

}

/// @nodoc


class _UiActualDeviceStreamConfig implements UiActualDeviceStreamConfig {
  const _UiActualDeviceStreamConfig({required this.hostName, required this.deviceId, required this.deviceName, required this.sampleRate, required this.callbackBufferSize, required this.channels});
  

@override final  String hostName;
@override final  String deviceId;
@override final  String deviceName;
@override final  int sampleRate;
@override final  int callbackBufferSize;
@override final  int channels;

/// Create a copy of UiActualDeviceStreamConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiActualDeviceStreamConfigCopyWith<_UiActualDeviceStreamConfig> get copyWith => __$UiActualDeviceStreamConfigCopyWithImpl<_UiActualDeviceStreamConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiActualDeviceStreamConfig&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.callbackBufferSize, callbackBufferSize) || other.callbackBufferSize == callbackBufferSize)&&(identical(other.channels, channels) || other.channels == channels));
}


@override
int get hashCode => Object.hash(runtimeType,hostName,deviceId,deviceName,sampleRate,callbackBufferSize,channels);

@override
String toString() {
  return 'UiActualDeviceStreamConfig(hostName: $hostName, deviceId: $deviceId, deviceName: $deviceName, sampleRate: $sampleRate, callbackBufferSize: $callbackBufferSize, channels: $channels)';
}


}

/// @nodoc
abstract mixin class _$UiActualDeviceStreamConfigCopyWith<$Res> implements $UiActualDeviceStreamConfigCopyWith<$Res> {
  factory _$UiActualDeviceStreamConfigCopyWith(_UiActualDeviceStreamConfig value, $Res Function(_UiActualDeviceStreamConfig) _then) = __$UiActualDeviceStreamConfigCopyWithImpl;
@override @useResult
$Res call({
 String hostName, String deviceId, String deviceName, int sampleRate, int callbackBufferSize, int channels
});




}
/// @nodoc
class __$UiActualDeviceStreamConfigCopyWithImpl<$Res>
    implements _$UiActualDeviceStreamConfigCopyWith<$Res> {
  __$UiActualDeviceStreamConfigCopyWithImpl(this._self, this._then);

  final _UiActualDeviceStreamConfig _self;
  final $Res Function(_UiActualDeviceStreamConfig) _then;

/// Create a copy of UiActualDeviceStreamConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostName = null,Object? deviceId = null,Object? deviceName = null,Object? sampleRate = null,Object? callbackBufferSize = null,Object? channels = null,}) {
  return _then(_UiActualDeviceStreamConfig(
hostName: null == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,deviceName: null == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,callbackBufferSize: null == callbackBufferSize ? _self.callbackBufferSize : callbackBufferSize // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiAudioHostInfo {

 String? get hostName; String get displayName;
/// Create a copy of UiAudioHostInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiAudioHostInfoCopyWith<UiAudioHostInfo> get copyWith => _$UiAudioHostInfoCopyWithImpl<UiAudioHostInfo>(this as UiAudioHostInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiAudioHostInfo&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}


@override
int get hashCode => Object.hash(runtimeType,hostName,displayName);

@override
String toString() {
  return 'UiAudioHostInfo(hostName: $hostName, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class $UiAudioHostInfoCopyWith<$Res>  {
  factory $UiAudioHostInfoCopyWith(UiAudioHostInfo value, $Res Function(UiAudioHostInfo) _then) = _$UiAudioHostInfoCopyWithImpl;
@useResult
$Res call({
 String? hostName, String displayName
});




}
/// @nodoc
class _$UiAudioHostInfoCopyWithImpl<$Res>
    implements $UiAudioHostInfoCopyWith<$Res> {
  _$UiAudioHostInfoCopyWithImpl(this._self, this._then);

  final UiAudioHostInfo _self;
  final $Res Function(UiAudioHostInfo) _then;

/// Create a copy of UiAudioHostInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostName = freezed,Object? displayName = null,}) {
  return _then(_self.copyWith(
hostName: freezed == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiAudioHostInfo].
extension UiAudioHostInfoPatterns on UiAudioHostInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiAudioHostInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiAudioHostInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiAudioHostInfo value)  $default,){
final _that = this;
switch (_that) {
case _UiAudioHostInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiAudioHostInfo value)?  $default,){
final _that = this;
switch (_that) {
case _UiAudioHostInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? hostName,  String displayName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiAudioHostInfo() when $default != null:
return $default(_that.hostName,_that.displayName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? hostName,  String displayName)  $default,) {final _that = this;
switch (_that) {
case _UiAudioHostInfo():
return $default(_that.hostName,_that.displayName);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? hostName,  String displayName)?  $default,) {final _that = this;
switch (_that) {
case _UiAudioHostInfo() when $default != null:
return $default(_that.hostName,_that.displayName);case _:
  return null;

}
}

}

/// @nodoc


class _UiAudioHostInfo implements UiAudioHostInfo {
  const _UiAudioHostInfo({this.hostName, required this.displayName});
  

@override final  String? hostName;
@override final  String displayName;

/// Create a copy of UiAudioHostInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiAudioHostInfoCopyWith<_UiAudioHostInfo> get copyWith => __$UiAudioHostInfoCopyWithImpl<_UiAudioHostInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiAudioHostInfo&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}


@override
int get hashCode => Object.hash(runtimeType,hostName,displayName);

@override
String toString() {
  return 'UiAudioHostInfo(hostName: $hostName, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class _$UiAudioHostInfoCopyWith<$Res> implements $UiAudioHostInfoCopyWith<$Res> {
  factory _$UiAudioHostInfoCopyWith(_UiAudioHostInfo value, $Res Function(_UiAudioHostInfo) _then) = __$UiAudioHostInfoCopyWithImpl;
@override @useResult
$Res call({
 String? hostName, String displayName
});




}
/// @nodoc
class __$UiAudioHostInfoCopyWithImpl<$Res>
    implements _$UiAudioHostInfoCopyWith<$Res> {
  __$UiAudioHostInfoCopyWithImpl(this._self, this._then);

  final _UiAudioHostInfo _self;
  final $Res Function(_UiAudioHostInfo) _then;

/// Create a copy of UiAudioHostInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostName = freezed,Object? displayName = null,}) {
  return _then(_UiAudioHostInfo(
hostName: freezed == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiAudioRuntimeSettings {

 UiRequestedOutputConfig get requestedOutput; UiRequestedDspConfig get requestedDsp; UiActualDeviceStreamConfig? get actualStream; UiDeviceStreamStatus get streamStatus;
/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiAudioRuntimeSettingsCopyWith<UiAudioRuntimeSettings> get copyWith => _$UiAudioRuntimeSettingsCopyWithImpl<UiAudioRuntimeSettings>(this as UiAudioRuntimeSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiAudioRuntimeSettings&&(identical(other.requestedOutput, requestedOutput) || other.requestedOutput == requestedOutput)&&(identical(other.requestedDsp, requestedDsp) || other.requestedDsp == requestedDsp)&&(identical(other.actualStream, actualStream) || other.actualStream == actualStream)&&(identical(other.streamStatus, streamStatus) || other.streamStatus == streamStatus));
}


@override
int get hashCode => Object.hash(runtimeType,requestedOutput,requestedDsp,actualStream,streamStatus);

@override
String toString() {
  return 'UiAudioRuntimeSettings(requestedOutput: $requestedOutput, requestedDsp: $requestedDsp, actualStream: $actualStream, streamStatus: $streamStatus)';
}


}

/// @nodoc
abstract mixin class $UiAudioRuntimeSettingsCopyWith<$Res>  {
  factory $UiAudioRuntimeSettingsCopyWith(UiAudioRuntimeSettings value, $Res Function(UiAudioRuntimeSettings) _then) = _$UiAudioRuntimeSettingsCopyWithImpl;
@useResult
$Res call({
 UiRequestedOutputConfig requestedOutput, UiRequestedDspConfig requestedDsp, UiActualDeviceStreamConfig? actualStream, UiDeviceStreamStatus streamStatus
});


$UiRequestedOutputConfigCopyWith<$Res> get requestedOutput;$UiRequestedDspConfigCopyWith<$Res> get requestedDsp;$UiActualDeviceStreamConfigCopyWith<$Res>? get actualStream;$UiDeviceStreamStatusCopyWith<$Res> get streamStatus;

}
/// @nodoc
class _$UiAudioRuntimeSettingsCopyWithImpl<$Res>
    implements $UiAudioRuntimeSettingsCopyWith<$Res> {
  _$UiAudioRuntimeSettingsCopyWithImpl(this._self, this._then);

  final UiAudioRuntimeSettings _self;
  final $Res Function(UiAudioRuntimeSettings) _then;

/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestedOutput = null,Object? requestedDsp = null,Object? actualStream = freezed,Object? streamStatus = null,}) {
  return _then(_self.copyWith(
requestedOutput: null == requestedOutput ? _self.requestedOutput : requestedOutput // ignore: cast_nullable_to_non_nullable
as UiRequestedOutputConfig,requestedDsp: null == requestedDsp ? _self.requestedDsp : requestedDsp // ignore: cast_nullable_to_non_nullable
as UiRequestedDspConfig,actualStream: freezed == actualStream ? _self.actualStream : actualStream // ignore: cast_nullable_to_non_nullable
as UiActualDeviceStreamConfig?,streamStatus: null == streamStatus ? _self.streamStatus : streamStatus // ignore: cast_nullable_to_non_nullable
as UiDeviceStreamStatus,
  ));
}
/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRequestedOutputConfigCopyWith<$Res> get requestedOutput {
  
  return $UiRequestedOutputConfigCopyWith<$Res>(_self.requestedOutput, (value) {
    return _then(_self.copyWith(requestedOutput: value));
  });
}/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRequestedDspConfigCopyWith<$Res> get requestedDsp {
  
  return $UiRequestedDspConfigCopyWith<$Res>(_self.requestedDsp, (value) {
    return _then(_self.copyWith(requestedDsp: value));
  });
}/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiActualDeviceStreamConfigCopyWith<$Res>? get actualStream {
    if (_self.actualStream == null) {
    return null;
  }

  return $UiActualDeviceStreamConfigCopyWith<$Res>(_self.actualStream!, (value) {
    return _then(_self.copyWith(actualStream: value));
  });
}/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiDeviceStreamStatusCopyWith<$Res> get streamStatus {
  
  return $UiDeviceStreamStatusCopyWith<$Res>(_self.streamStatus, (value) {
    return _then(_self.copyWith(streamStatus: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiAudioRuntimeSettings].
extension UiAudioRuntimeSettingsPatterns on UiAudioRuntimeSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiAudioRuntimeSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiAudioRuntimeSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiAudioRuntimeSettings value)  $default,){
final _that = this;
switch (_that) {
case _UiAudioRuntimeSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiAudioRuntimeSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UiAudioRuntimeSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiRequestedOutputConfig requestedOutput,  UiRequestedDspConfig requestedDsp,  UiActualDeviceStreamConfig? actualStream,  UiDeviceStreamStatus streamStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiAudioRuntimeSettings() when $default != null:
return $default(_that.requestedOutput,_that.requestedDsp,_that.actualStream,_that.streamStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiRequestedOutputConfig requestedOutput,  UiRequestedDspConfig requestedDsp,  UiActualDeviceStreamConfig? actualStream,  UiDeviceStreamStatus streamStatus)  $default,) {final _that = this;
switch (_that) {
case _UiAudioRuntimeSettings():
return $default(_that.requestedOutput,_that.requestedDsp,_that.actualStream,_that.streamStatus);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiRequestedOutputConfig requestedOutput,  UiRequestedDspConfig requestedDsp,  UiActualDeviceStreamConfig? actualStream,  UiDeviceStreamStatus streamStatus)?  $default,) {final _that = this;
switch (_that) {
case _UiAudioRuntimeSettings() when $default != null:
return $default(_that.requestedOutput,_that.requestedDsp,_that.actualStream,_that.streamStatus);case _:
  return null;

}
}

}

/// @nodoc


class _UiAudioRuntimeSettings implements UiAudioRuntimeSettings {
  const _UiAudioRuntimeSettings({required this.requestedOutput, required this.requestedDsp, this.actualStream, required this.streamStatus});
  

@override final  UiRequestedOutputConfig requestedOutput;
@override final  UiRequestedDspConfig requestedDsp;
@override final  UiActualDeviceStreamConfig? actualStream;
@override final  UiDeviceStreamStatus streamStatus;

/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiAudioRuntimeSettingsCopyWith<_UiAudioRuntimeSettings> get copyWith => __$UiAudioRuntimeSettingsCopyWithImpl<_UiAudioRuntimeSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiAudioRuntimeSettings&&(identical(other.requestedOutput, requestedOutput) || other.requestedOutput == requestedOutput)&&(identical(other.requestedDsp, requestedDsp) || other.requestedDsp == requestedDsp)&&(identical(other.actualStream, actualStream) || other.actualStream == actualStream)&&(identical(other.streamStatus, streamStatus) || other.streamStatus == streamStatus));
}


@override
int get hashCode => Object.hash(runtimeType,requestedOutput,requestedDsp,actualStream,streamStatus);

@override
String toString() {
  return 'UiAudioRuntimeSettings(requestedOutput: $requestedOutput, requestedDsp: $requestedDsp, actualStream: $actualStream, streamStatus: $streamStatus)';
}


}

/// @nodoc
abstract mixin class _$UiAudioRuntimeSettingsCopyWith<$Res> implements $UiAudioRuntimeSettingsCopyWith<$Res> {
  factory _$UiAudioRuntimeSettingsCopyWith(_UiAudioRuntimeSettings value, $Res Function(_UiAudioRuntimeSettings) _then) = __$UiAudioRuntimeSettingsCopyWithImpl;
@override @useResult
$Res call({
 UiRequestedOutputConfig requestedOutput, UiRequestedDspConfig requestedDsp, UiActualDeviceStreamConfig? actualStream, UiDeviceStreamStatus streamStatus
});


@override $UiRequestedOutputConfigCopyWith<$Res> get requestedOutput;@override $UiRequestedDspConfigCopyWith<$Res> get requestedDsp;@override $UiActualDeviceStreamConfigCopyWith<$Res>? get actualStream;@override $UiDeviceStreamStatusCopyWith<$Res> get streamStatus;

}
/// @nodoc
class __$UiAudioRuntimeSettingsCopyWithImpl<$Res>
    implements _$UiAudioRuntimeSettingsCopyWith<$Res> {
  __$UiAudioRuntimeSettingsCopyWithImpl(this._self, this._then);

  final _UiAudioRuntimeSettings _self;
  final $Res Function(_UiAudioRuntimeSettings) _then;

/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestedOutput = null,Object? requestedDsp = null,Object? actualStream = freezed,Object? streamStatus = null,}) {
  return _then(_UiAudioRuntimeSettings(
requestedOutput: null == requestedOutput ? _self.requestedOutput : requestedOutput // ignore: cast_nullable_to_non_nullable
as UiRequestedOutputConfig,requestedDsp: null == requestedDsp ? _self.requestedDsp : requestedDsp // ignore: cast_nullable_to_non_nullable
as UiRequestedDspConfig,actualStream: freezed == actualStream ? _self.actualStream : actualStream // ignore: cast_nullable_to_non_nullable
as UiActualDeviceStreamConfig?,streamStatus: null == streamStatus ? _self.streamStatus : streamStatus // ignore: cast_nullable_to_non_nullable
as UiDeviceStreamStatus,
  ));
}

/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRequestedOutputConfigCopyWith<$Res> get requestedOutput {
  
  return $UiRequestedOutputConfigCopyWith<$Res>(_self.requestedOutput, (value) {
    return _then(_self.copyWith(requestedOutput: value));
  });
}/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRequestedDspConfigCopyWith<$Res> get requestedDsp {
  
  return $UiRequestedDspConfigCopyWith<$Res>(_self.requestedDsp, (value) {
    return _then(_self.copyWith(requestedDsp: value));
  });
}/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiActualDeviceStreamConfigCopyWith<$Res>? get actualStream {
    if (_self.actualStream == null) {
    return null;
  }

  return $UiActualDeviceStreamConfigCopyWith<$Res>(_self.actualStream!, (value) {
    return _then(_self.copyWith(actualStream: value));
  });
}/// Create a copy of UiAudioRuntimeSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiDeviceStreamStatusCopyWith<$Res> get streamStatus {
  
  return $UiDeviceStreamStatusCopyWith<$Res>(_self.streamStatus, (value) {
    return _then(_self.copyWith(streamStatus: value));
  });
}
}

/// @nodoc
mixin _$UiDeviceStreamStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiDeviceStreamStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiDeviceStreamStatus()';
}


}

/// @nodoc
class $UiDeviceStreamStatusCopyWith<$Res>  {
$UiDeviceStreamStatusCopyWith(UiDeviceStreamStatus _, $Res Function(UiDeviceStreamStatus) __);
}


/// Adds pattern-matching-related methods to [UiDeviceStreamStatus].
extension UiDeviceStreamStatusPatterns on UiDeviceStreamStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiDeviceStreamStatus_Starting value)?  starting,TResult Function( UiDeviceStreamStatus_Running value)?  running,TResult Function( UiDeviceStreamStatus_Retrying value)?  retrying,TResult Function( UiDeviceStreamStatus_Unavailable value)?  unavailable,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiDeviceStreamStatus_Starting() when starting != null:
return starting(_that);case UiDeviceStreamStatus_Running() when running != null:
return running(_that);case UiDeviceStreamStatus_Retrying() when retrying != null:
return retrying(_that);case UiDeviceStreamStatus_Unavailable() when unavailable != null:
return unavailable(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiDeviceStreamStatus_Starting value)  starting,required TResult Function( UiDeviceStreamStatus_Running value)  running,required TResult Function( UiDeviceStreamStatus_Retrying value)  retrying,required TResult Function( UiDeviceStreamStatus_Unavailable value)  unavailable,}){
final _that = this;
switch (_that) {
case UiDeviceStreamStatus_Starting():
return starting(_that);case UiDeviceStreamStatus_Running():
return running(_that);case UiDeviceStreamStatus_Retrying():
return retrying(_that);case UiDeviceStreamStatus_Unavailable():
return unavailable(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiDeviceStreamStatus_Starting value)?  starting,TResult? Function( UiDeviceStreamStatus_Running value)?  running,TResult? Function( UiDeviceStreamStatus_Retrying value)?  retrying,TResult? Function( UiDeviceStreamStatus_Unavailable value)?  unavailable,}){
final _that = this;
switch (_that) {
case UiDeviceStreamStatus_Starting() when starting != null:
return starting(_that);case UiDeviceStreamStatus_Running() when running != null:
return running(_that);case UiDeviceStreamStatus_Retrying() when retrying != null:
return retrying(_that);case UiDeviceStreamStatus_Unavailable() when unavailable != null:
return unavailable(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  starting,TResult Function()?  running,TResult Function( String reason)?  retrying,TResult Function( String reason)?  unavailable,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiDeviceStreamStatus_Starting() when starting != null:
return starting();case UiDeviceStreamStatus_Running() when running != null:
return running();case UiDeviceStreamStatus_Retrying() when retrying != null:
return retrying(_that.reason);case UiDeviceStreamStatus_Unavailable() when unavailable != null:
return unavailable(_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  starting,required TResult Function()  running,required TResult Function( String reason)  retrying,required TResult Function( String reason)  unavailable,}) {final _that = this;
switch (_that) {
case UiDeviceStreamStatus_Starting():
return starting();case UiDeviceStreamStatus_Running():
return running();case UiDeviceStreamStatus_Retrying():
return retrying(_that.reason);case UiDeviceStreamStatus_Unavailable():
return unavailable(_that.reason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  starting,TResult? Function()?  running,TResult? Function( String reason)?  retrying,TResult? Function( String reason)?  unavailable,}) {final _that = this;
switch (_that) {
case UiDeviceStreamStatus_Starting() when starting != null:
return starting();case UiDeviceStreamStatus_Running() when running != null:
return running();case UiDeviceStreamStatus_Retrying() when retrying != null:
return retrying(_that.reason);case UiDeviceStreamStatus_Unavailable() when unavailable != null:
return unavailable(_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class UiDeviceStreamStatus_Starting extends UiDeviceStreamStatus {
  const UiDeviceStreamStatus_Starting(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiDeviceStreamStatus_Starting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiDeviceStreamStatus.starting()';
}


}




/// @nodoc


class UiDeviceStreamStatus_Running extends UiDeviceStreamStatus {
  const UiDeviceStreamStatus_Running(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiDeviceStreamStatus_Running);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiDeviceStreamStatus.running()';
}


}




/// @nodoc


class UiDeviceStreamStatus_Retrying extends UiDeviceStreamStatus {
  const UiDeviceStreamStatus_Retrying({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of UiDeviceStreamStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiDeviceStreamStatus_RetryingCopyWith<UiDeviceStreamStatus_Retrying> get copyWith => _$UiDeviceStreamStatus_RetryingCopyWithImpl<UiDeviceStreamStatus_Retrying>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiDeviceStreamStatus_Retrying&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'UiDeviceStreamStatus.retrying(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $UiDeviceStreamStatus_RetryingCopyWith<$Res> implements $UiDeviceStreamStatusCopyWith<$Res> {
  factory $UiDeviceStreamStatus_RetryingCopyWith(UiDeviceStreamStatus_Retrying value, $Res Function(UiDeviceStreamStatus_Retrying) _then) = _$UiDeviceStreamStatus_RetryingCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$UiDeviceStreamStatus_RetryingCopyWithImpl<$Res>
    implements $UiDeviceStreamStatus_RetryingCopyWith<$Res> {
  _$UiDeviceStreamStatus_RetryingCopyWithImpl(this._self, this._then);

  final UiDeviceStreamStatus_Retrying _self;
  final $Res Function(UiDeviceStreamStatus_Retrying) _then;

/// Create a copy of UiDeviceStreamStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(UiDeviceStreamStatus_Retrying(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class UiDeviceStreamStatus_Unavailable extends UiDeviceStreamStatus {
  const UiDeviceStreamStatus_Unavailable({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of UiDeviceStreamStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiDeviceStreamStatus_UnavailableCopyWith<UiDeviceStreamStatus_Unavailable> get copyWith => _$UiDeviceStreamStatus_UnavailableCopyWithImpl<UiDeviceStreamStatus_Unavailable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiDeviceStreamStatus_Unavailable&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'UiDeviceStreamStatus.unavailable(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $UiDeviceStreamStatus_UnavailableCopyWith<$Res> implements $UiDeviceStreamStatusCopyWith<$Res> {
  factory $UiDeviceStreamStatus_UnavailableCopyWith(UiDeviceStreamStatus_Unavailable value, $Res Function(UiDeviceStreamStatus_Unavailable) _then) = _$UiDeviceStreamStatus_UnavailableCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$UiDeviceStreamStatus_UnavailableCopyWithImpl<$Res>
    implements $UiDeviceStreamStatus_UnavailableCopyWith<$Res> {
  _$UiDeviceStreamStatus_UnavailableCopyWithImpl(this._self, this._then);

  final UiDeviceStreamStatus_Unavailable _self;
  final $Res Function(UiDeviceStreamStatus_Unavailable) _then;

/// Create a copy of UiDeviceStreamStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(UiDeviceStreamStatus_Unavailable(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiOutputDeviceInfo {

 String? get deviceId; String get displayName; bool get isCurrentSystemDefault;
/// Create a copy of UiOutputDeviceInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiOutputDeviceInfoCopyWith<UiOutputDeviceInfo> get copyWith => _$UiOutputDeviceInfoCopyWithImpl<UiOutputDeviceInfo>(this as UiOutputDeviceInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiOutputDeviceInfo&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isCurrentSystemDefault, isCurrentSystemDefault) || other.isCurrentSystemDefault == isCurrentSystemDefault));
}


@override
int get hashCode => Object.hash(runtimeType,deviceId,displayName,isCurrentSystemDefault);

@override
String toString() {
  return 'UiOutputDeviceInfo(deviceId: $deviceId, displayName: $displayName, isCurrentSystemDefault: $isCurrentSystemDefault)';
}


}

/// @nodoc
abstract mixin class $UiOutputDeviceInfoCopyWith<$Res>  {
  factory $UiOutputDeviceInfoCopyWith(UiOutputDeviceInfo value, $Res Function(UiOutputDeviceInfo) _then) = _$UiOutputDeviceInfoCopyWithImpl;
@useResult
$Res call({
 String? deviceId, String displayName, bool isCurrentSystemDefault
});




}
/// @nodoc
class _$UiOutputDeviceInfoCopyWithImpl<$Res>
    implements $UiOutputDeviceInfoCopyWith<$Res> {
  _$UiOutputDeviceInfoCopyWithImpl(this._self, this._then);

  final UiOutputDeviceInfo _self;
  final $Res Function(UiOutputDeviceInfo) _then;

/// Create a copy of UiOutputDeviceInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceId = freezed,Object? displayName = null,Object? isCurrentSystemDefault = null,}) {
  return _then(_self.copyWith(
deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isCurrentSystemDefault: null == isCurrentSystemDefault ? _self.isCurrentSystemDefault : isCurrentSystemDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UiOutputDeviceInfo].
extension UiOutputDeviceInfoPatterns on UiOutputDeviceInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiOutputDeviceInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiOutputDeviceInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiOutputDeviceInfo value)  $default,){
final _that = this;
switch (_that) {
case _UiOutputDeviceInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiOutputDeviceInfo value)?  $default,){
final _that = this;
switch (_that) {
case _UiOutputDeviceInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? deviceId,  String displayName,  bool isCurrentSystemDefault)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiOutputDeviceInfo() when $default != null:
return $default(_that.deviceId,_that.displayName,_that.isCurrentSystemDefault);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? deviceId,  String displayName,  bool isCurrentSystemDefault)  $default,) {final _that = this;
switch (_that) {
case _UiOutputDeviceInfo():
return $default(_that.deviceId,_that.displayName,_that.isCurrentSystemDefault);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? deviceId,  String displayName,  bool isCurrentSystemDefault)?  $default,) {final _that = this;
switch (_that) {
case _UiOutputDeviceInfo() when $default != null:
return $default(_that.deviceId,_that.displayName,_that.isCurrentSystemDefault);case _:
  return null;

}
}

}

/// @nodoc


class _UiOutputDeviceInfo implements UiOutputDeviceInfo {
  const _UiOutputDeviceInfo({this.deviceId, required this.displayName, required this.isCurrentSystemDefault});
  

@override final  String? deviceId;
@override final  String displayName;
@override final  bool isCurrentSystemDefault;

/// Create a copy of UiOutputDeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiOutputDeviceInfoCopyWith<_UiOutputDeviceInfo> get copyWith => __$UiOutputDeviceInfoCopyWithImpl<_UiOutputDeviceInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiOutputDeviceInfo&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isCurrentSystemDefault, isCurrentSystemDefault) || other.isCurrentSystemDefault == isCurrentSystemDefault));
}


@override
int get hashCode => Object.hash(runtimeType,deviceId,displayName,isCurrentSystemDefault);

@override
String toString() {
  return 'UiOutputDeviceInfo(deviceId: $deviceId, displayName: $displayName, isCurrentSystemDefault: $isCurrentSystemDefault)';
}


}

/// @nodoc
abstract mixin class _$UiOutputDeviceInfoCopyWith<$Res> implements $UiOutputDeviceInfoCopyWith<$Res> {
  factory _$UiOutputDeviceInfoCopyWith(_UiOutputDeviceInfo value, $Res Function(_UiOutputDeviceInfo) _then) = __$UiOutputDeviceInfoCopyWithImpl;
@override @useResult
$Res call({
 String? deviceId, String displayName, bool isCurrentSystemDefault
});




}
/// @nodoc
class __$UiOutputDeviceInfoCopyWithImpl<$Res>
    implements _$UiOutputDeviceInfoCopyWith<$Res> {
  __$UiOutputDeviceInfoCopyWithImpl(this._self, this._then);

  final _UiOutputDeviceInfo _self;
  final $Res Function(_UiOutputDeviceInfo) _then;

/// Create a copy of UiOutputDeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceId = freezed,Object? displayName = null,Object? isCurrentSystemDefault = null,}) {
  return _then(_UiOutputDeviceInfo(
deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isCurrentSystemDefault: null == isCurrentSystemDefault ? _self.isCurrentSystemDefault : isCurrentSystemDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$UiOutputDeviceSelection {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiOutputDeviceSelection);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiOutputDeviceSelection()';
}


}

/// @nodoc
class $UiOutputDeviceSelectionCopyWith<$Res>  {
$UiOutputDeviceSelectionCopyWith(UiOutputDeviceSelection _, $Res Function(UiOutputDeviceSelection) __);
}


/// Adds pattern-matching-related methods to [UiOutputDeviceSelection].
extension UiOutputDeviceSelectionPatterns on UiOutputDeviceSelection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiOutputDeviceSelection_SystemDefault value)?  systemDefault,TResult Function( UiOutputDeviceSelection_Specific value)?  specific,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiOutputDeviceSelection_SystemDefault() when systemDefault != null:
return systemDefault(_that);case UiOutputDeviceSelection_Specific() when specific != null:
return specific(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiOutputDeviceSelection_SystemDefault value)  systemDefault,required TResult Function( UiOutputDeviceSelection_Specific value)  specific,}){
final _that = this;
switch (_that) {
case UiOutputDeviceSelection_SystemDefault():
return systemDefault(_that);case UiOutputDeviceSelection_Specific():
return specific(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiOutputDeviceSelection_SystemDefault value)?  systemDefault,TResult? Function( UiOutputDeviceSelection_Specific value)?  specific,}){
final _that = this;
switch (_that) {
case UiOutputDeviceSelection_SystemDefault() when systemDefault != null:
return systemDefault(_that);case UiOutputDeviceSelection_Specific() when specific != null:
return specific(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  systemDefault,TResult Function( String id,  String name)?  specific,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiOutputDeviceSelection_SystemDefault() when systemDefault != null:
return systemDefault();case UiOutputDeviceSelection_Specific() when specific != null:
return specific(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  systemDefault,required TResult Function( String id,  String name)  specific,}) {final _that = this;
switch (_that) {
case UiOutputDeviceSelection_SystemDefault():
return systemDefault();case UiOutputDeviceSelection_Specific():
return specific(_that.id,_that.name);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  systemDefault,TResult? Function( String id,  String name)?  specific,}) {final _that = this;
switch (_that) {
case UiOutputDeviceSelection_SystemDefault() when systemDefault != null:
return systemDefault();case UiOutputDeviceSelection_Specific() when specific != null:
return specific(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class UiOutputDeviceSelection_SystemDefault extends UiOutputDeviceSelection {
  const UiOutputDeviceSelection_SystemDefault(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiOutputDeviceSelection_SystemDefault);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiOutputDeviceSelection.systemDefault()';
}


}




/// @nodoc


class UiOutputDeviceSelection_Specific extends UiOutputDeviceSelection {
  const UiOutputDeviceSelection_Specific({required this.id, required this.name}): super._();
  

 final  String id;
 final  String name;

/// Create a copy of UiOutputDeviceSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiOutputDeviceSelection_SpecificCopyWith<UiOutputDeviceSelection_Specific> get copyWith => _$UiOutputDeviceSelection_SpecificCopyWithImpl<UiOutputDeviceSelection_Specific>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiOutputDeviceSelection_Specific&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'UiOutputDeviceSelection.specific(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $UiOutputDeviceSelection_SpecificCopyWith<$Res> implements $UiOutputDeviceSelectionCopyWith<$Res> {
  factory $UiOutputDeviceSelection_SpecificCopyWith(UiOutputDeviceSelection_Specific value, $Res Function(UiOutputDeviceSelection_Specific) _then) = _$UiOutputDeviceSelection_SpecificCopyWithImpl;
@useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class _$UiOutputDeviceSelection_SpecificCopyWithImpl<$Res>
    implements $UiOutputDeviceSelection_SpecificCopyWith<$Res> {
  _$UiOutputDeviceSelection_SpecificCopyWithImpl(this._self, this._then);

  final UiOutputDeviceSelection_Specific _self;
  final $Res Function(UiOutputDeviceSelection_Specific) _then;

/// Create a copy of UiOutputDeviceSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(UiOutputDeviceSelection_Specific(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiOutputHostSelection {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiOutputHostSelection);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiOutputHostSelection()';
}


}

/// @nodoc
class $UiOutputHostSelectionCopyWith<$Res>  {
$UiOutputHostSelectionCopyWith(UiOutputHostSelection _, $Res Function(UiOutputHostSelection) __);
}


/// Adds pattern-matching-related methods to [UiOutputHostSelection].
extension UiOutputHostSelectionPatterns on UiOutputHostSelection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiOutputHostSelection_SystemDefault value)?  systemDefault,TResult Function( UiOutputHostSelection_Named value)?  named,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiOutputHostSelection_SystemDefault() when systemDefault != null:
return systemDefault(_that);case UiOutputHostSelection_Named() when named != null:
return named(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiOutputHostSelection_SystemDefault value)  systemDefault,required TResult Function( UiOutputHostSelection_Named value)  named,}){
final _that = this;
switch (_that) {
case UiOutputHostSelection_SystemDefault():
return systemDefault(_that);case UiOutputHostSelection_Named():
return named(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiOutputHostSelection_SystemDefault value)?  systemDefault,TResult? Function( UiOutputHostSelection_Named value)?  named,}){
final _that = this;
switch (_that) {
case UiOutputHostSelection_SystemDefault() when systemDefault != null:
return systemDefault(_that);case UiOutputHostSelection_Named() when named != null:
return named(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  systemDefault,TResult Function( String name)?  named,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiOutputHostSelection_SystemDefault() when systemDefault != null:
return systemDefault();case UiOutputHostSelection_Named() when named != null:
return named(_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  systemDefault,required TResult Function( String name)  named,}) {final _that = this;
switch (_that) {
case UiOutputHostSelection_SystemDefault():
return systemDefault();case UiOutputHostSelection_Named():
return named(_that.name);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  systemDefault,TResult? Function( String name)?  named,}) {final _that = this;
switch (_that) {
case UiOutputHostSelection_SystemDefault() when systemDefault != null:
return systemDefault();case UiOutputHostSelection_Named() when named != null:
return named(_that.name);case _:
  return null;

}
}

}

/// @nodoc


class UiOutputHostSelection_SystemDefault extends UiOutputHostSelection {
  const UiOutputHostSelection_SystemDefault(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiOutputHostSelection_SystemDefault);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiOutputHostSelection.systemDefault()';
}


}




/// @nodoc


class UiOutputHostSelection_Named extends UiOutputHostSelection {
  const UiOutputHostSelection_Named({required this.name}): super._();
  

 final  String name;

/// Create a copy of UiOutputHostSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiOutputHostSelection_NamedCopyWith<UiOutputHostSelection_Named> get copyWith => _$UiOutputHostSelection_NamedCopyWithImpl<UiOutputHostSelection_Named>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiOutputHostSelection_Named&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'UiOutputHostSelection.named(name: $name)';
}


}

/// @nodoc
abstract mixin class $UiOutputHostSelection_NamedCopyWith<$Res> implements $UiOutputHostSelectionCopyWith<$Res> {
  factory $UiOutputHostSelection_NamedCopyWith(UiOutputHostSelection_Named value, $Res Function(UiOutputHostSelection_Named) _then) = _$UiOutputHostSelection_NamedCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$UiOutputHostSelection_NamedCopyWithImpl<$Res>
    implements $UiOutputHostSelection_NamedCopyWith<$Res> {
  _$UiOutputHostSelection_NamedCopyWithImpl(this._self, this._then);

  final UiOutputHostSelection_Named _self;
  final $Res Function(UiOutputHostSelection_Named) _then;

/// Create a copy of UiOutputHostSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(UiOutputHostSelection_Named(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiRequestedDspConfig {

 int get sampleRate; int get blockSize;
/// Create a copy of UiRequestedDspConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiRequestedDspConfigCopyWith<UiRequestedDspConfig> get copyWith => _$UiRequestedDspConfigCopyWithImpl<UiRequestedDspConfig>(this as UiRequestedDspConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRequestedDspConfig&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.blockSize, blockSize) || other.blockSize == blockSize));
}


@override
int get hashCode => Object.hash(runtimeType,sampleRate,blockSize);

@override
String toString() {
  return 'UiRequestedDspConfig(sampleRate: $sampleRate, blockSize: $blockSize)';
}


}

/// @nodoc
abstract mixin class $UiRequestedDspConfigCopyWith<$Res>  {
  factory $UiRequestedDspConfigCopyWith(UiRequestedDspConfig value, $Res Function(UiRequestedDspConfig) _then) = _$UiRequestedDspConfigCopyWithImpl;
@useResult
$Res call({
 int sampleRate, int blockSize
});




}
/// @nodoc
class _$UiRequestedDspConfigCopyWithImpl<$Res>
    implements $UiRequestedDspConfigCopyWith<$Res> {
  _$UiRequestedDspConfigCopyWithImpl(this._self, this._then);

  final UiRequestedDspConfig _self;
  final $Res Function(UiRequestedDspConfig) _then;

/// Create a copy of UiRequestedDspConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sampleRate = null,Object? blockSize = null,}) {
  return _then(_self.copyWith(
sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,blockSize: null == blockSize ? _self.blockSize : blockSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiRequestedDspConfig].
extension UiRequestedDspConfigPatterns on UiRequestedDspConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiRequestedDspConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiRequestedDspConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiRequestedDspConfig value)  $default,){
final _that = this;
switch (_that) {
case _UiRequestedDspConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiRequestedDspConfig value)?  $default,){
final _that = this;
switch (_that) {
case _UiRequestedDspConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sampleRate,  int blockSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiRequestedDspConfig() when $default != null:
return $default(_that.sampleRate,_that.blockSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sampleRate,  int blockSize)  $default,) {final _that = this;
switch (_that) {
case _UiRequestedDspConfig():
return $default(_that.sampleRate,_that.blockSize);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sampleRate,  int blockSize)?  $default,) {final _that = this;
switch (_that) {
case _UiRequestedDspConfig() when $default != null:
return $default(_that.sampleRate,_that.blockSize);case _:
  return null;

}
}

}

/// @nodoc


class _UiRequestedDspConfig implements UiRequestedDspConfig {
  const _UiRequestedDspConfig({required this.sampleRate, required this.blockSize});
  

@override final  int sampleRate;
@override final  int blockSize;

/// Create a copy of UiRequestedDspConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiRequestedDspConfigCopyWith<_UiRequestedDspConfig> get copyWith => __$UiRequestedDspConfigCopyWithImpl<_UiRequestedDspConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiRequestedDspConfig&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.blockSize, blockSize) || other.blockSize == blockSize));
}


@override
int get hashCode => Object.hash(runtimeType,sampleRate,blockSize);

@override
String toString() {
  return 'UiRequestedDspConfig(sampleRate: $sampleRate, blockSize: $blockSize)';
}


}

/// @nodoc
abstract mixin class _$UiRequestedDspConfigCopyWith<$Res> implements $UiRequestedDspConfigCopyWith<$Res> {
  factory _$UiRequestedDspConfigCopyWith(_UiRequestedDspConfig value, $Res Function(_UiRequestedDspConfig) _then) = __$UiRequestedDspConfigCopyWithImpl;
@override @useResult
$Res call({
 int sampleRate, int blockSize
});




}
/// @nodoc
class __$UiRequestedDspConfigCopyWithImpl<$Res>
    implements _$UiRequestedDspConfigCopyWith<$Res> {
  __$UiRequestedDspConfigCopyWithImpl(this._self, this._then);

  final _UiRequestedDspConfig _self;
  final $Res Function(_UiRequestedDspConfig) _then;

/// Create a copy of UiRequestedDspConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sampleRate = null,Object? blockSize = null,}) {
  return _then(_UiRequestedDspConfig(
sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,blockSize: null == blockSize ? _self.blockSize : blockSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiRequestedOutputConfig {

 UiOutputHostSelection get host; UiOutputDeviceSelection get device;
/// Create a copy of UiRequestedOutputConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiRequestedOutputConfigCopyWith<UiRequestedOutputConfig> get copyWith => _$UiRequestedOutputConfigCopyWithImpl<UiRequestedOutputConfig>(this as UiRequestedOutputConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRequestedOutputConfig&&(identical(other.host, host) || other.host == host)&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,host,device);

@override
String toString() {
  return 'UiRequestedOutputConfig(host: $host, device: $device)';
}


}

/// @nodoc
abstract mixin class $UiRequestedOutputConfigCopyWith<$Res>  {
  factory $UiRequestedOutputConfigCopyWith(UiRequestedOutputConfig value, $Res Function(UiRequestedOutputConfig) _then) = _$UiRequestedOutputConfigCopyWithImpl;
@useResult
$Res call({
 UiOutputHostSelection host, UiOutputDeviceSelection device
});


$UiOutputHostSelectionCopyWith<$Res> get host;$UiOutputDeviceSelectionCopyWith<$Res> get device;

}
/// @nodoc
class _$UiRequestedOutputConfigCopyWithImpl<$Res>
    implements $UiRequestedOutputConfigCopyWith<$Res> {
  _$UiRequestedOutputConfigCopyWithImpl(this._self, this._then);

  final UiRequestedOutputConfig _self;
  final $Res Function(UiRequestedOutputConfig) _then;

/// Create a copy of UiRequestedOutputConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? host = null,Object? device = null,}) {
  return _then(_self.copyWith(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UiOutputHostSelection,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as UiOutputDeviceSelection,
  ));
}
/// Create a copy of UiRequestedOutputConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiOutputHostSelectionCopyWith<$Res> get host {
  
  return $UiOutputHostSelectionCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}/// Create a copy of UiRequestedOutputConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiOutputDeviceSelectionCopyWith<$Res> get device {
  
  return $UiOutputDeviceSelectionCopyWith<$Res>(_self.device, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiRequestedOutputConfig].
extension UiRequestedOutputConfigPatterns on UiRequestedOutputConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiRequestedOutputConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiRequestedOutputConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiRequestedOutputConfig value)  $default,){
final _that = this;
switch (_that) {
case _UiRequestedOutputConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiRequestedOutputConfig value)?  $default,){
final _that = this;
switch (_that) {
case _UiRequestedOutputConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiOutputHostSelection host,  UiOutputDeviceSelection device)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiRequestedOutputConfig() when $default != null:
return $default(_that.host,_that.device);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiOutputHostSelection host,  UiOutputDeviceSelection device)  $default,) {final _that = this;
switch (_that) {
case _UiRequestedOutputConfig():
return $default(_that.host,_that.device);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiOutputHostSelection host,  UiOutputDeviceSelection device)?  $default,) {final _that = this;
switch (_that) {
case _UiRequestedOutputConfig() when $default != null:
return $default(_that.host,_that.device);case _:
  return null;

}
}

}

/// @nodoc


class _UiRequestedOutputConfig implements UiRequestedOutputConfig {
  const _UiRequestedOutputConfig({required this.host, required this.device});
  

@override final  UiOutputHostSelection host;
@override final  UiOutputDeviceSelection device;

/// Create a copy of UiRequestedOutputConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiRequestedOutputConfigCopyWith<_UiRequestedOutputConfig> get copyWith => __$UiRequestedOutputConfigCopyWithImpl<_UiRequestedOutputConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiRequestedOutputConfig&&(identical(other.host, host) || other.host == host)&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,host,device);

@override
String toString() {
  return 'UiRequestedOutputConfig(host: $host, device: $device)';
}


}

/// @nodoc
abstract mixin class _$UiRequestedOutputConfigCopyWith<$Res> implements $UiRequestedOutputConfigCopyWith<$Res> {
  factory _$UiRequestedOutputConfigCopyWith(_UiRequestedOutputConfig value, $Res Function(_UiRequestedOutputConfig) _then) = __$UiRequestedOutputConfigCopyWithImpl;
@override @useResult
$Res call({
 UiOutputHostSelection host, UiOutputDeviceSelection device
});


@override $UiOutputHostSelectionCopyWith<$Res> get host;@override $UiOutputDeviceSelectionCopyWith<$Res> get device;

}
/// @nodoc
class __$UiRequestedOutputConfigCopyWithImpl<$Res>
    implements _$UiRequestedOutputConfigCopyWith<$Res> {
  __$UiRequestedOutputConfigCopyWithImpl(this._self, this._then);

  final _UiRequestedOutputConfig _self;
  final $Res Function(_UiRequestedOutputConfig) _then;

/// Create a copy of UiRequestedOutputConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = null,Object? device = null,}) {
  return _then(_UiRequestedOutputConfig(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UiOutputHostSelection,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as UiOutputDeviceSelection,
  ));
}

/// Create a copy of UiRequestedOutputConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiOutputHostSelectionCopyWith<$Res> get host {
  
  return $UiOutputHostSelectionCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}/// Create a copy of UiRequestedOutputConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiOutputDeviceSelectionCopyWith<$Res> get device {
  
  return $UiOutputDeviceSelectionCopyWith<$Res>(_self.device, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}

// dart format on
