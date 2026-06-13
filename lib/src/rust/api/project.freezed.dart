// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioExportConfigDTO {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioExportConfigDTO&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'AudioExportConfigDTO(field0: $field0)';
}


}

/// @nodoc
class $AudioExportConfigDTOCopyWith<$Res>  {
$AudioExportConfigDTOCopyWith(AudioExportConfigDTO _, $Res Function(AudioExportConfigDTO) __);
}


/// Adds pattern-matching-related methods to [AudioExportConfigDTO].
extension AudioExportConfigDTOPatterns on AudioExportConfigDTO {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AudioExportConfigDTO_Wav value)?  wav,TResult Function( AudioExportConfigDTO_Mp3 value)?  mp3,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AudioExportConfigDTO_Wav() when wav != null:
return wav(_that);case AudioExportConfigDTO_Mp3() when mp3 != null:
return mp3(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AudioExportConfigDTO_Wav value)  wav,required TResult Function( AudioExportConfigDTO_Mp3 value)  mp3,}){
final _that = this;
switch (_that) {
case AudioExportConfigDTO_Wav():
return wav(_that);case AudioExportConfigDTO_Mp3():
return mp3(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AudioExportConfigDTO_Wav value)?  wav,TResult? Function( AudioExportConfigDTO_Mp3 value)?  mp3,}){
final _that = this;
switch (_that) {
case AudioExportConfigDTO_Wav() when wav != null:
return wav(_that);case AudioExportConfigDTO_Mp3() when mp3 != null:
return mp3(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( WavExportConfigDTO field0)?  wav,TResult Function( Mp3ExportConfigDTO field0)?  mp3,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AudioExportConfigDTO_Wav() when wav != null:
return wav(_that.field0);case AudioExportConfigDTO_Mp3() when mp3 != null:
return mp3(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( WavExportConfigDTO field0)  wav,required TResult Function( Mp3ExportConfigDTO field0)  mp3,}) {final _that = this;
switch (_that) {
case AudioExportConfigDTO_Wav():
return wav(_that.field0);case AudioExportConfigDTO_Mp3():
return mp3(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( WavExportConfigDTO field0)?  wav,TResult? Function( Mp3ExportConfigDTO field0)?  mp3,}) {final _that = this;
switch (_that) {
case AudioExportConfigDTO_Wav() when wav != null:
return wav(_that.field0);case AudioExportConfigDTO_Mp3() when mp3 != null:
return mp3(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class AudioExportConfigDTO_Wav extends AudioExportConfigDTO {
  const AudioExportConfigDTO_Wav(this.field0): super._();
  

@override final  WavExportConfigDTO field0;

/// Create a copy of AudioExportConfigDTO
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioExportConfigDTO_WavCopyWith<AudioExportConfigDTO_Wav> get copyWith => _$AudioExportConfigDTO_WavCopyWithImpl<AudioExportConfigDTO_Wav>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioExportConfigDTO_Wav&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'AudioExportConfigDTO.wav(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $AudioExportConfigDTO_WavCopyWith<$Res> implements $AudioExportConfigDTOCopyWith<$Res> {
  factory $AudioExportConfigDTO_WavCopyWith(AudioExportConfigDTO_Wav value, $Res Function(AudioExportConfigDTO_Wav) _then) = _$AudioExportConfigDTO_WavCopyWithImpl;
@useResult
$Res call({
 WavExportConfigDTO field0
});




}
/// @nodoc
class _$AudioExportConfigDTO_WavCopyWithImpl<$Res>
    implements $AudioExportConfigDTO_WavCopyWith<$Res> {
  _$AudioExportConfigDTO_WavCopyWithImpl(this._self, this._then);

  final AudioExportConfigDTO_Wav _self;
  final $Res Function(AudioExportConfigDTO_Wav) _then;

/// Create a copy of AudioExportConfigDTO
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(AudioExportConfigDTO_Wav(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as WavExportConfigDTO,
  ));
}


}

/// @nodoc


class AudioExportConfigDTO_Mp3 extends AudioExportConfigDTO {
  const AudioExportConfigDTO_Mp3(this.field0): super._();
  

@override final  Mp3ExportConfigDTO field0;

/// Create a copy of AudioExportConfigDTO
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioExportConfigDTO_Mp3CopyWith<AudioExportConfigDTO_Mp3> get copyWith => _$AudioExportConfigDTO_Mp3CopyWithImpl<AudioExportConfigDTO_Mp3>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioExportConfigDTO_Mp3&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'AudioExportConfigDTO.mp3(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $AudioExportConfigDTO_Mp3CopyWith<$Res> implements $AudioExportConfigDTOCopyWith<$Res> {
  factory $AudioExportConfigDTO_Mp3CopyWith(AudioExportConfigDTO_Mp3 value, $Res Function(AudioExportConfigDTO_Mp3) _then) = _$AudioExportConfigDTO_Mp3CopyWithImpl;
@useResult
$Res call({
 Mp3ExportConfigDTO field0
});




}
/// @nodoc
class _$AudioExportConfigDTO_Mp3CopyWithImpl<$Res>
    implements $AudioExportConfigDTO_Mp3CopyWith<$Res> {
  _$AudioExportConfigDTO_Mp3CopyWithImpl(this._self, this._then);

  final AudioExportConfigDTO_Mp3 _self;
  final $Res Function(AudioExportConfigDTO_Mp3) _then;

/// Create a copy of AudioExportConfigDTO
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(AudioExportConfigDTO_Mp3(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as Mp3ExportConfigDTO,
  ));
}


}

/// @nodoc
mixin _$AudioWaveformUiForSourceList {

 String get name; bool get muted; int get sampleRate;
/// Create a copy of AudioWaveformUiForSourceList
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioWaveformUiForSourceListCopyWith<AudioWaveformUiForSourceList> get copyWith => _$AudioWaveformUiForSourceListCopyWithImpl<AudioWaveformUiForSourceList>(this as AudioWaveformUiForSourceList, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioWaveformUiForSourceList&&(identical(other.name, name) || other.name == name)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate));
}


@override
int get hashCode => Object.hash(runtimeType,name,muted,sampleRate);

@override
String toString() {
  return 'AudioWaveformUiForSourceList(name: $name, muted: $muted, sampleRate: $sampleRate)';
}


}

/// @nodoc
abstract mixin class $AudioWaveformUiForSourceListCopyWith<$Res>  {
  factory $AudioWaveformUiForSourceListCopyWith(AudioWaveformUiForSourceList value, $Res Function(AudioWaveformUiForSourceList) _then) = _$AudioWaveformUiForSourceListCopyWithImpl;
@useResult
$Res call({
 String name, bool muted, int sampleRate
});




}
/// @nodoc
class _$AudioWaveformUiForSourceListCopyWithImpl<$Res>
    implements $AudioWaveformUiForSourceListCopyWith<$Res> {
  _$AudioWaveformUiForSourceListCopyWithImpl(this._self, this._then);

  final AudioWaveformUiForSourceList _self;
  final $Res Function(AudioWaveformUiForSourceList) _then;

/// Create a copy of AudioWaveformUiForSourceList
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? muted = null,Object? sampleRate = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioWaveformUiForSourceList].
extension AudioWaveformUiForSourceListPatterns on AudioWaveformUiForSourceList {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioWaveformUiForSourceList value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioWaveformUiForSourceList() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioWaveformUiForSourceList value)  $default,){
final _that = this;
switch (_that) {
case _AudioWaveformUiForSourceList():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioWaveformUiForSourceList value)?  $default,){
final _that = this;
switch (_that) {
case _AudioWaveformUiForSourceList() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  bool muted,  int sampleRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioWaveformUiForSourceList() when $default != null:
return $default(_that.name,_that.muted,_that.sampleRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  bool muted,  int sampleRate)  $default,) {final _that = this;
switch (_that) {
case _AudioWaveformUiForSourceList():
return $default(_that.name,_that.muted,_that.sampleRate);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  bool muted,  int sampleRate)?  $default,) {final _that = this;
switch (_that) {
case _AudioWaveformUiForSourceList() when $default != null:
return $default(_that.name,_that.muted,_that.sampleRate);case _:
  return null;

}
}

}

/// @nodoc


class _AudioWaveformUiForSourceList implements AudioWaveformUiForSourceList {
  const _AudioWaveformUiForSourceList({required this.name, required this.muted, required this.sampleRate});
  

@override final  String name;
@override final  bool muted;
@override final  int sampleRate;

/// Create a copy of AudioWaveformUiForSourceList
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioWaveformUiForSourceListCopyWith<_AudioWaveformUiForSourceList> get copyWith => __$AudioWaveformUiForSourceListCopyWithImpl<_AudioWaveformUiForSourceList>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioWaveformUiForSourceList&&(identical(other.name, name) || other.name == name)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate));
}


@override
int get hashCode => Object.hash(runtimeType,name,muted,sampleRate);

@override
String toString() {
  return 'AudioWaveformUiForSourceList(name: $name, muted: $muted, sampleRate: $sampleRate)';
}


}

/// @nodoc
abstract mixin class _$AudioWaveformUiForSourceListCopyWith<$Res> implements $AudioWaveformUiForSourceListCopyWith<$Res> {
  factory _$AudioWaveformUiForSourceListCopyWith(_AudioWaveformUiForSourceList value, $Res Function(_AudioWaveformUiForSourceList) _then) = __$AudioWaveformUiForSourceListCopyWithImpl;
@override @useResult
$Res call({
 String name, bool muted, int sampleRate
});




}
/// @nodoc
class __$AudioWaveformUiForSourceListCopyWithImpl<$Res>
    implements _$AudioWaveformUiForSourceListCopyWith<$Res> {
  __$AudioWaveformUiForSourceListCopyWithImpl(this._self, this._then);

  final _AudioWaveformUiForSourceList _self;
  final $Res Function(_AudioWaveformUiForSourceList) _then;

/// Create a copy of AudioWaveformUiForSourceList
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? muted = null,Object? sampleRate = null,}) {
  return _then(_AudioWaveformUiForSourceList(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$BitDepthDTO {

 int get field0;
/// Create a copy of BitDepthDTO
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BitDepthDTOCopyWith<BitDepthDTO> get copyWith => _$BitDepthDTOCopyWithImpl<BitDepthDTO>(this as BitDepthDTO, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BitDepthDTO&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'BitDepthDTO(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $BitDepthDTOCopyWith<$Res>  {
  factory $BitDepthDTOCopyWith(BitDepthDTO value, $Res Function(BitDepthDTO) _then) = _$BitDepthDTOCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$BitDepthDTOCopyWithImpl<$Res>
    implements $BitDepthDTOCopyWith<$Res> {
  _$BitDepthDTOCopyWithImpl(this._self, this._then);

  final BitDepthDTO _self;
  final $Res Function(BitDepthDTO) _then;

/// Create a copy of BitDepthDTO
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? field0 = null,}) {
  return _then(_self.copyWith(
field0: null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BitDepthDTO].
extension BitDepthDTOPatterns on BitDepthDTO {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BitDepthDTO_BitPerSample value)?  bitPerSample,TResult Function( BitDepthDTO_BitPerSecond value)?  bitPerSecond,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BitDepthDTO_BitPerSample() when bitPerSample != null:
return bitPerSample(_that);case BitDepthDTO_BitPerSecond() when bitPerSecond != null:
return bitPerSecond(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BitDepthDTO_BitPerSample value)  bitPerSample,required TResult Function( BitDepthDTO_BitPerSecond value)  bitPerSecond,}){
final _that = this;
switch (_that) {
case BitDepthDTO_BitPerSample():
return bitPerSample(_that);case BitDepthDTO_BitPerSecond():
return bitPerSecond(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BitDepthDTO_BitPerSample value)?  bitPerSample,TResult? Function( BitDepthDTO_BitPerSecond value)?  bitPerSecond,}){
final _that = this;
switch (_that) {
case BitDepthDTO_BitPerSample() when bitPerSample != null:
return bitPerSample(_that);case BitDepthDTO_BitPerSecond() when bitPerSecond != null:
return bitPerSecond(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int field0)?  bitPerSample,TResult Function( int field0)?  bitPerSecond,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BitDepthDTO_BitPerSample() when bitPerSample != null:
return bitPerSample(_that.field0);case BitDepthDTO_BitPerSecond() when bitPerSecond != null:
return bitPerSecond(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int field0)  bitPerSample,required TResult Function( int field0)  bitPerSecond,}) {final _that = this;
switch (_that) {
case BitDepthDTO_BitPerSample():
return bitPerSample(_that.field0);case BitDepthDTO_BitPerSecond():
return bitPerSecond(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int field0)?  bitPerSample,TResult? Function( int field0)?  bitPerSecond,}) {final _that = this;
switch (_that) {
case BitDepthDTO_BitPerSample() when bitPerSample != null:
return bitPerSample(_that.field0);case BitDepthDTO_BitPerSecond() when bitPerSecond != null:
return bitPerSecond(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class BitDepthDTO_BitPerSample extends BitDepthDTO {
  const BitDepthDTO_BitPerSample(this.field0): super._();
  

@override final  int field0;

/// Create a copy of BitDepthDTO
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BitDepthDTO_BitPerSampleCopyWith<BitDepthDTO_BitPerSample> get copyWith => _$BitDepthDTO_BitPerSampleCopyWithImpl<BitDepthDTO_BitPerSample>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BitDepthDTO_BitPerSample&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'BitDepthDTO.bitPerSample(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $BitDepthDTO_BitPerSampleCopyWith<$Res> implements $BitDepthDTOCopyWith<$Res> {
  factory $BitDepthDTO_BitPerSampleCopyWith(BitDepthDTO_BitPerSample value, $Res Function(BitDepthDTO_BitPerSample) _then) = _$BitDepthDTO_BitPerSampleCopyWithImpl;
@override @useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$BitDepthDTO_BitPerSampleCopyWithImpl<$Res>
    implements $BitDepthDTO_BitPerSampleCopyWith<$Res> {
  _$BitDepthDTO_BitPerSampleCopyWithImpl(this._self, this._then);

  final BitDepthDTO_BitPerSample _self;
  final $Res Function(BitDepthDTO_BitPerSample) _then;

/// Create a copy of BitDepthDTO
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(BitDepthDTO_BitPerSample(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class BitDepthDTO_BitPerSecond extends BitDepthDTO {
  const BitDepthDTO_BitPerSecond(this.field0): super._();
  

@override final  int field0;

/// Create a copy of BitDepthDTO
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BitDepthDTO_BitPerSecondCopyWith<BitDepthDTO_BitPerSecond> get copyWith => _$BitDepthDTO_BitPerSecondCopyWithImpl<BitDepthDTO_BitPerSecond>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BitDepthDTO_BitPerSecond&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'BitDepthDTO.bitPerSecond(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $BitDepthDTO_BitPerSecondCopyWith<$Res> implements $BitDepthDTOCopyWith<$Res> {
  factory $BitDepthDTO_BitPerSecondCopyWith(BitDepthDTO_BitPerSecond value, $Res Function(BitDepthDTO_BitPerSecond) _then) = _$BitDepthDTO_BitPerSecondCopyWithImpl;
@override @useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$BitDepthDTO_BitPerSecondCopyWithImpl<$Res>
    implements $BitDepthDTO_BitPerSecondCopyWith<$Res> {
  _$BitDepthDTO_BitPerSecondCopyWithImpl(this._self, this._then);

  final BitDepthDTO_BitPerSecond _self;
  final $Res Function(BitDepthDTO_BitPerSecond) _then;

/// Create a copy of BitDepthDTO
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(BitDepthDTO_BitPerSecond(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiAudioHardwareConfig {

 String get selectedInputDevice; String get selectedOutputDevice; int get sampleRate; int get bufferSize; double get cpuLoad;
/// Create a copy of UiAudioHardwareConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiAudioHardwareConfigCopyWith<UiAudioHardwareConfig> get copyWith => _$UiAudioHardwareConfigCopyWithImpl<UiAudioHardwareConfig>(this as UiAudioHardwareConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiAudioHardwareConfig&&(identical(other.selectedInputDevice, selectedInputDevice) || other.selectedInputDevice == selectedInputDevice)&&(identical(other.selectedOutputDevice, selectedOutputDevice) || other.selectedOutputDevice == selectedOutputDevice)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.bufferSize, bufferSize) || other.bufferSize == bufferSize)&&(identical(other.cpuLoad, cpuLoad) || other.cpuLoad == cpuLoad));
}


@override
int get hashCode => Object.hash(runtimeType,selectedInputDevice,selectedOutputDevice,sampleRate,bufferSize,cpuLoad);

@override
String toString() {
  return 'UiAudioHardwareConfig(selectedInputDevice: $selectedInputDevice, selectedOutputDevice: $selectedOutputDevice, sampleRate: $sampleRate, bufferSize: $bufferSize, cpuLoad: $cpuLoad)';
}


}

/// @nodoc
abstract mixin class $UiAudioHardwareConfigCopyWith<$Res>  {
  factory $UiAudioHardwareConfigCopyWith(UiAudioHardwareConfig value, $Res Function(UiAudioHardwareConfig) _then) = _$UiAudioHardwareConfigCopyWithImpl;
@useResult
$Res call({
 String selectedInputDevice, String selectedOutputDevice, int sampleRate, int bufferSize, double cpuLoad
});




}
/// @nodoc
class _$UiAudioHardwareConfigCopyWithImpl<$Res>
    implements $UiAudioHardwareConfigCopyWith<$Res> {
  _$UiAudioHardwareConfigCopyWithImpl(this._self, this._then);

  final UiAudioHardwareConfig _self;
  final $Res Function(UiAudioHardwareConfig) _then;

/// Create a copy of UiAudioHardwareConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedInputDevice = null,Object? selectedOutputDevice = null,Object? sampleRate = null,Object? bufferSize = null,Object? cpuLoad = null,}) {
  return _then(_self.copyWith(
selectedInputDevice: null == selectedInputDevice ? _self.selectedInputDevice : selectedInputDevice // ignore: cast_nullable_to_non_nullable
as String,selectedOutputDevice: null == selectedOutputDevice ? _self.selectedOutputDevice : selectedOutputDevice // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,bufferSize: null == bufferSize ? _self.bufferSize : bufferSize // ignore: cast_nullable_to_non_nullable
as int,cpuLoad: null == cpuLoad ? _self.cpuLoad : cpuLoad // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [UiAudioHardwareConfig].
extension UiAudioHardwareConfigPatterns on UiAudioHardwareConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiAudioHardwareConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiAudioHardwareConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiAudioHardwareConfig value)  $default,){
final _that = this;
switch (_that) {
case _UiAudioHardwareConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiAudioHardwareConfig value)?  $default,){
final _that = this;
switch (_that) {
case _UiAudioHardwareConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String selectedInputDevice,  String selectedOutputDevice,  int sampleRate,  int bufferSize,  double cpuLoad)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiAudioHardwareConfig() when $default != null:
return $default(_that.selectedInputDevice,_that.selectedOutputDevice,_that.sampleRate,_that.bufferSize,_that.cpuLoad);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String selectedInputDevice,  String selectedOutputDevice,  int sampleRate,  int bufferSize,  double cpuLoad)  $default,) {final _that = this;
switch (_that) {
case _UiAudioHardwareConfig():
return $default(_that.selectedInputDevice,_that.selectedOutputDevice,_that.sampleRate,_that.bufferSize,_that.cpuLoad);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String selectedInputDevice,  String selectedOutputDevice,  int sampleRate,  int bufferSize,  double cpuLoad)?  $default,) {final _that = this;
switch (_that) {
case _UiAudioHardwareConfig() when $default != null:
return $default(_that.selectedInputDevice,_that.selectedOutputDevice,_that.sampleRate,_that.bufferSize,_that.cpuLoad);case _:
  return null;

}
}

}

/// @nodoc


class _UiAudioHardwareConfig implements UiAudioHardwareConfig {
  const _UiAudioHardwareConfig({required this.selectedInputDevice, required this.selectedOutputDevice, required this.sampleRate, required this.bufferSize, required this.cpuLoad});
  

@override final  String selectedInputDevice;
@override final  String selectedOutputDevice;
@override final  int sampleRate;
@override final  int bufferSize;
@override final  double cpuLoad;

/// Create a copy of UiAudioHardwareConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiAudioHardwareConfigCopyWith<_UiAudioHardwareConfig> get copyWith => __$UiAudioHardwareConfigCopyWithImpl<_UiAudioHardwareConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiAudioHardwareConfig&&(identical(other.selectedInputDevice, selectedInputDevice) || other.selectedInputDevice == selectedInputDevice)&&(identical(other.selectedOutputDevice, selectedOutputDevice) || other.selectedOutputDevice == selectedOutputDevice)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.bufferSize, bufferSize) || other.bufferSize == bufferSize)&&(identical(other.cpuLoad, cpuLoad) || other.cpuLoad == cpuLoad));
}


@override
int get hashCode => Object.hash(runtimeType,selectedInputDevice,selectedOutputDevice,sampleRate,bufferSize,cpuLoad);

@override
String toString() {
  return 'UiAudioHardwareConfig(selectedInputDevice: $selectedInputDevice, selectedOutputDevice: $selectedOutputDevice, sampleRate: $sampleRate, bufferSize: $bufferSize, cpuLoad: $cpuLoad)';
}


}

/// @nodoc
abstract mixin class _$UiAudioHardwareConfigCopyWith<$Res> implements $UiAudioHardwareConfigCopyWith<$Res> {
  factory _$UiAudioHardwareConfigCopyWith(_UiAudioHardwareConfig value, $Res Function(_UiAudioHardwareConfig) _then) = __$UiAudioHardwareConfigCopyWithImpl;
@override @useResult
$Res call({
 String selectedInputDevice, String selectedOutputDevice, int sampleRate, int bufferSize, double cpuLoad
});




}
/// @nodoc
class __$UiAudioHardwareConfigCopyWithImpl<$Res>
    implements _$UiAudioHardwareConfigCopyWith<$Res> {
  __$UiAudioHardwareConfigCopyWithImpl(this._self, this._then);

  final _UiAudioHardwareConfig _self;
  final $Res Function(_UiAudioHardwareConfig) _then;

/// Create a copy of UiAudioHardwareConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedInputDevice = null,Object? selectedOutputDevice = null,Object? sampleRate = null,Object? bufferSize = null,Object? cpuLoad = null,}) {
  return _then(_UiAudioHardwareConfig(
selectedInputDevice: null == selectedInputDevice ? _self.selectedInputDevice : selectedInputDevice // ignore: cast_nullable_to_non_nullable
as String,selectedOutputDevice: null == selectedOutputDevice ? _self.selectedOutputDevice : selectedOutputDevice // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,bufferSize: null == bufferSize ? _self.bufferSize : bufferSize // ignore: cast_nullable_to_non_nullable
as int,cpuLoad: null == cpuLoad ? _self.cpuLoad : cpuLoad // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$UiClip {

 String get name; int get id; int get startTime; UiClipSource get source; int get offsetStart; int get loopLength; bool get isSampleBased;
/// Create a copy of UiClip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiClipCopyWith<UiClip> get copyWith => _$UiClipCopyWithImpl<UiClip>(this as UiClip, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiClip&&(identical(other.name, name) || other.name == name)&&(identical(other.id, id) || other.id == id)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.source, source) || other.source == source)&&(identical(other.offsetStart, offsetStart) || other.offsetStart == offsetStart)&&(identical(other.loopLength, loopLength) || other.loopLength == loopLength)&&(identical(other.isSampleBased, isSampleBased) || other.isSampleBased == isSampleBased));
}


@override
int get hashCode => Object.hash(runtimeType,name,id,startTime,source,offsetStart,loopLength,isSampleBased);

@override
String toString() {
  return 'UiClip(name: $name, id: $id, startTime: $startTime, source: $source, offsetStart: $offsetStart, loopLength: $loopLength, isSampleBased: $isSampleBased)';
}


}

/// @nodoc
abstract mixin class $UiClipCopyWith<$Res>  {
  factory $UiClipCopyWith(UiClip value, $Res Function(UiClip) _then) = _$UiClipCopyWithImpl;
@useResult
$Res call({
 String name, int id, int startTime, UiClipSource source, int offsetStart, int loopLength, bool isSampleBased
});


$UiClipSourceCopyWith<$Res> get source;

}
/// @nodoc
class _$UiClipCopyWithImpl<$Res>
    implements $UiClipCopyWith<$Res> {
  _$UiClipCopyWithImpl(this._self, this._then);

  final UiClip _self;
  final $Res Function(UiClip) _then;

/// Create a copy of UiClip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? id = null,Object? startTime = null,Object? source = null,Object? offsetStart = null,Object? loopLength = null,Object? isSampleBased = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as UiClipSource,offsetStart: null == offsetStart ? _self.offsetStart : offsetStart // ignore: cast_nullable_to_non_nullable
as int,loopLength: null == loopLength ? _self.loopLength : loopLength // ignore: cast_nullable_to_non_nullable
as int,isSampleBased: null == isSampleBased ? _self.isSampleBased : isSampleBased // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of UiClip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiClipSourceCopyWith<$Res> get source {
  
  return $UiClipSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiClip].
extension UiClipPatterns on UiClip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiClip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiClip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiClip value)  $default,){
final _that = this;
switch (_that) {
case _UiClip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiClip value)?  $default,){
final _that = this;
switch (_that) {
case _UiClip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int id,  int startTime,  UiClipSource source,  int offsetStart,  int loopLength,  bool isSampleBased)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiClip() when $default != null:
return $default(_that.name,_that.id,_that.startTime,_that.source,_that.offsetStart,_that.loopLength,_that.isSampleBased);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int id,  int startTime,  UiClipSource source,  int offsetStart,  int loopLength,  bool isSampleBased)  $default,) {final _that = this;
switch (_that) {
case _UiClip():
return $default(_that.name,_that.id,_that.startTime,_that.source,_that.offsetStart,_that.loopLength,_that.isSampleBased);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int id,  int startTime,  UiClipSource source,  int offsetStart,  int loopLength,  bool isSampleBased)?  $default,) {final _that = this;
switch (_that) {
case _UiClip() when $default != null:
return $default(_that.name,_that.id,_that.startTime,_that.source,_that.offsetStart,_that.loopLength,_that.isSampleBased);case _:
  return null;

}
}

}

/// @nodoc


class _UiClip implements UiClip {
  const _UiClip({required this.name, required this.id, required this.startTime, required this.source, required this.offsetStart, required this.loopLength, required this.isSampleBased});
  

@override final  String name;
@override final  int id;
@override final  int startTime;
@override final  UiClipSource source;
@override final  int offsetStart;
@override final  int loopLength;
@override final  bool isSampleBased;

/// Create a copy of UiClip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiClipCopyWith<_UiClip> get copyWith => __$UiClipCopyWithImpl<_UiClip>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiClip&&(identical(other.name, name) || other.name == name)&&(identical(other.id, id) || other.id == id)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.source, source) || other.source == source)&&(identical(other.offsetStart, offsetStart) || other.offsetStart == offsetStart)&&(identical(other.loopLength, loopLength) || other.loopLength == loopLength)&&(identical(other.isSampleBased, isSampleBased) || other.isSampleBased == isSampleBased));
}


@override
int get hashCode => Object.hash(runtimeType,name,id,startTime,source,offsetStart,loopLength,isSampleBased);

@override
String toString() {
  return 'UiClip(name: $name, id: $id, startTime: $startTime, source: $source, offsetStart: $offsetStart, loopLength: $loopLength, isSampleBased: $isSampleBased)';
}


}

/// @nodoc
abstract mixin class _$UiClipCopyWith<$Res> implements $UiClipCopyWith<$Res> {
  factory _$UiClipCopyWith(_UiClip value, $Res Function(_UiClip) _then) = __$UiClipCopyWithImpl;
@override @useResult
$Res call({
 String name, int id, int startTime, UiClipSource source, int offsetStart, int loopLength, bool isSampleBased
});


@override $UiClipSourceCopyWith<$Res> get source;

}
/// @nodoc
class __$UiClipCopyWithImpl<$Res>
    implements _$UiClipCopyWith<$Res> {
  __$UiClipCopyWithImpl(this._self, this._then);

  final _UiClip _self;
  final $Res Function(_UiClip) _then;

/// Create a copy of UiClip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? id = null,Object? startTime = null,Object? source = null,Object? offsetStart = null,Object? loopLength = null,Object? isSampleBased = null,}) {
  return _then(_UiClip(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as UiClipSource,offsetStart: null == offsetStart ? _self.offsetStart : offsetStart // ignore: cast_nullable_to_non_nullable
as int,loopLength: null == loopLength ? _self.loopLength : loopLength // ignore: cast_nullable_to_non_nullable
as int,isSampleBased: null == isSampleBased ? _self.isSampleBased : isSampleBased // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of UiClip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiClipSourceCopyWith<$Res> get source {
  
  return $UiClipSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}

/// @nodoc
mixin _$UiClipSource {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiClipSource);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiClipSource()';
}


}

/// @nodoc
class $UiClipSourceCopyWith<$Res>  {
$UiClipSourceCopyWith(UiClipSource _, $Res Function(UiClipSource) __);
}


/// Adds pattern-matching-related methods to [UiClipSource].
extension UiClipSourcePatterns on UiClipSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiClipSource_Audio value)?  audio,TResult Function( UiClipSource_Midi value)?  midi,TResult Function( UiClipSource_None value)?  none,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiClipSource_Audio() when audio != null:
return audio(_that);case UiClipSource_Midi() when midi != null:
return midi(_that);case UiClipSource_None() when none != null:
return none(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiClipSource_Audio value)  audio,required TResult Function( UiClipSource_Midi value)  midi,required TResult Function( UiClipSource_None value)  none,}){
final _that = this;
switch (_that) {
case UiClipSource_Audio():
return audio(_that);case UiClipSource_Midi():
return midi(_that);case UiClipSource_None():
return none(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiClipSource_Audio value)?  audio,TResult? Function( UiClipSource_Midi value)?  midi,TResult? Function( UiClipSource_None value)?  none,}){
final _that = this;
switch (_that) {
case UiClipSource_Audio() when audio != null:
return audio(_that);case UiClipSource_Midi() when midi != null:
return midi(_that);case UiClipSource_None() when none != null:
return none(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int sourceId)?  audio,TResult Function( int patternId)?  midi,TResult Function()?  none,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiClipSource_Audio() when audio != null:
return audio(_that.sourceId);case UiClipSource_Midi() when midi != null:
return midi(_that.patternId);case UiClipSource_None() when none != null:
return none();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int sourceId)  audio,required TResult Function( int patternId)  midi,required TResult Function()  none,}) {final _that = this;
switch (_that) {
case UiClipSource_Audio():
return audio(_that.sourceId);case UiClipSource_Midi():
return midi(_that.patternId);case UiClipSource_None():
return none();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int sourceId)?  audio,TResult? Function( int patternId)?  midi,TResult? Function()?  none,}) {final _that = this;
switch (_that) {
case UiClipSource_Audio() when audio != null:
return audio(_that.sourceId);case UiClipSource_Midi() when midi != null:
return midi(_that.patternId);case UiClipSource_None() when none != null:
return none();case _:
  return null;

}
}

}

/// @nodoc


class UiClipSource_Audio extends UiClipSource {
  const UiClipSource_Audio({required this.sourceId}): super._();
  

 final  int sourceId;

/// Create a copy of UiClipSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiClipSource_AudioCopyWith<UiClipSource_Audio> get copyWith => _$UiClipSource_AudioCopyWithImpl<UiClipSource_Audio>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiClipSource_Audio&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId));
}


@override
int get hashCode => Object.hash(runtimeType,sourceId);

@override
String toString() {
  return 'UiClipSource.audio(sourceId: $sourceId)';
}


}

/// @nodoc
abstract mixin class $UiClipSource_AudioCopyWith<$Res> implements $UiClipSourceCopyWith<$Res> {
  factory $UiClipSource_AudioCopyWith(UiClipSource_Audio value, $Res Function(UiClipSource_Audio) _then) = _$UiClipSource_AudioCopyWithImpl;
@useResult
$Res call({
 int sourceId
});




}
/// @nodoc
class _$UiClipSource_AudioCopyWithImpl<$Res>
    implements $UiClipSource_AudioCopyWith<$Res> {
  _$UiClipSource_AudioCopyWithImpl(this._self, this._then);

  final UiClipSource_Audio _self;
  final $Res Function(UiClipSource_Audio) _then;

/// Create a copy of UiClipSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sourceId = null,}) {
  return _then(UiClipSource_Audio(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiClipSource_Midi extends UiClipSource {
  const UiClipSource_Midi({required this.patternId}): super._();
  

 final  int patternId;

/// Create a copy of UiClipSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiClipSource_MidiCopyWith<UiClipSource_Midi> get copyWith => _$UiClipSource_MidiCopyWithImpl<UiClipSource_Midi>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiClipSource_Midi&&(identical(other.patternId, patternId) || other.patternId == patternId));
}


@override
int get hashCode => Object.hash(runtimeType,patternId);

@override
String toString() {
  return 'UiClipSource.midi(patternId: $patternId)';
}


}

/// @nodoc
abstract mixin class $UiClipSource_MidiCopyWith<$Res> implements $UiClipSourceCopyWith<$Res> {
  factory $UiClipSource_MidiCopyWith(UiClipSource_Midi value, $Res Function(UiClipSource_Midi) _then) = _$UiClipSource_MidiCopyWithImpl;
@useResult
$Res call({
 int patternId
});




}
/// @nodoc
class _$UiClipSource_MidiCopyWithImpl<$Res>
    implements $UiClipSource_MidiCopyWith<$Res> {
  _$UiClipSource_MidiCopyWithImpl(this._self, this._then);

  final UiClipSource_Midi _self;
  final $Res Function(UiClipSource_Midi) _then;

/// Create a copy of UiClipSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? patternId = null,}) {
  return _then(UiClipSource_Midi(
patternId: null == patternId ? _self.patternId : patternId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiClipSource_None extends UiClipSource {
  const UiClipSource_None(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiClipSource_None);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiClipSource.none()';
}


}




/// @nodoc
mixin _$UiGeneratorInstance {

 int get id; UiGeneratorInstanceType get instanceType;
/// Create a copy of UiGeneratorInstance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiGeneratorInstanceCopyWith<UiGeneratorInstance> get copyWith => _$UiGeneratorInstanceCopyWithImpl<UiGeneratorInstance>(this as UiGeneratorInstance, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiGeneratorInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.instanceType, instanceType) || other.instanceType == instanceType));
}


@override
int get hashCode => Object.hash(runtimeType,id,instanceType);

@override
String toString() {
  return 'UiGeneratorInstance(id: $id, instanceType: $instanceType)';
}


}

/// @nodoc
abstract mixin class $UiGeneratorInstanceCopyWith<$Res>  {
  factory $UiGeneratorInstanceCopyWith(UiGeneratorInstance value, $Res Function(UiGeneratorInstance) _then) = _$UiGeneratorInstanceCopyWithImpl;
@useResult
$Res call({
 int id, UiGeneratorInstanceType instanceType
});


$UiGeneratorInstanceTypeCopyWith<$Res> get instanceType;

}
/// @nodoc
class _$UiGeneratorInstanceCopyWithImpl<$Res>
    implements $UiGeneratorInstanceCopyWith<$Res> {
  _$UiGeneratorInstanceCopyWithImpl(this._self, this._then);

  final UiGeneratorInstance _self;
  final $Res Function(UiGeneratorInstance) _then;

/// Create a copy of UiGeneratorInstance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? instanceType = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,instanceType: null == instanceType ? _self.instanceType : instanceType // ignore: cast_nullable_to_non_nullable
as UiGeneratorInstanceType,
  ));
}
/// Create a copy of UiGeneratorInstance
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiGeneratorInstanceTypeCopyWith<$Res> get instanceType {
  
  return $UiGeneratorInstanceTypeCopyWith<$Res>(_self.instanceType, (value) {
    return _then(_self.copyWith(instanceType: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiGeneratorInstance].
extension UiGeneratorInstancePatterns on UiGeneratorInstance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiGeneratorInstance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiGeneratorInstance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiGeneratorInstance value)  $default,){
final _that = this;
switch (_that) {
case _UiGeneratorInstance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiGeneratorInstance value)?  $default,){
final _that = this;
switch (_that) {
case _UiGeneratorInstance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  UiGeneratorInstanceType instanceType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiGeneratorInstance() when $default != null:
return $default(_that.id,_that.instanceType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  UiGeneratorInstanceType instanceType)  $default,) {final _that = this;
switch (_that) {
case _UiGeneratorInstance():
return $default(_that.id,_that.instanceType);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  UiGeneratorInstanceType instanceType)?  $default,) {final _that = this;
switch (_that) {
case _UiGeneratorInstance() when $default != null:
return $default(_that.id,_that.instanceType);case _:
  return null;

}
}

}

/// @nodoc


class _UiGeneratorInstance implements UiGeneratorInstance {
  const _UiGeneratorInstance({required this.id, required this.instanceType});
  

@override final  int id;
@override final  UiGeneratorInstanceType instanceType;

/// Create a copy of UiGeneratorInstance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiGeneratorInstanceCopyWith<_UiGeneratorInstance> get copyWith => __$UiGeneratorInstanceCopyWithImpl<_UiGeneratorInstance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiGeneratorInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.instanceType, instanceType) || other.instanceType == instanceType));
}


@override
int get hashCode => Object.hash(runtimeType,id,instanceType);

@override
String toString() {
  return 'UiGeneratorInstance(id: $id, instanceType: $instanceType)';
}


}

/// @nodoc
abstract mixin class _$UiGeneratorInstanceCopyWith<$Res> implements $UiGeneratorInstanceCopyWith<$Res> {
  factory _$UiGeneratorInstanceCopyWith(_UiGeneratorInstance value, $Res Function(_UiGeneratorInstance) _then) = __$UiGeneratorInstanceCopyWithImpl;
@override @useResult
$Res call({
 int id, UiGeneratorInstanceType instanceType
});


@override $UiGeneratorInstanceTypeCopyWith<$Res> get instanceType;

}
/// @nodoc
class __$UiGeneratorInstanceCopyWithImpl<$Res>
    implements _$UiGeneratorInstanceCopyWith<$Res> {
  __$UiGeneratorInstanceCopyWithImpl(this._self, this._then);

  final _UiGeneratorInstance _self;
  final $Res Function(_UiGeneratorInstance) _then;

/// Create a copy of UiGeneratorInstance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? instanceType = null,}) {
  return _then(_UiGeneratorInstance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,instanceType: null == instanceType ? _self.instanceType : instanceType // ignore: cast_nullable_to_non_nullable
as UiGeneratorInstanceType,
  ));
}

/// Create a copy of UiGeneratorInstance
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiGeneratorInstanceTypeCopyWith<$Res> get instanceType {
  
  return $UiGeneratorInstanceTypeCopyWith<$Res>(_self.instanceType, (value) {
    return _then(_self.copyWith(instanceType: value));
  });
}
}

/// @nodoc
mixin _$UiGeneratorInstanceType {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiGeneratorInstanceType);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiGeneratorInstanceType()';
}


}

/// @nodoc
class $UiGeneratorInstanceTypeCopyWith<$Res>  {
$UiGeneratorInstanceTypeCopyWith(UiGeneratorInstanceType _, $Res Function(UiGeneratorInstanceType) __);
}


/// Adds pattern-matching-related methods to [UiGeneratorInstanceType].
extension UiGeneratorInstanceTypePatterns on UiGeneratorInstanceType {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiGeneratorInstanceType_Plugin value)?  plugin,TResult Function( UiGeneratorInstanceType_Sampler value)?  sampler,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiGeneratorInstanceType_Plugin() when plugin != null:
return plugin(_that);case UiGeneratorInstanceType_Sampler() when sampler != null:
return sampler(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiGeneratorInstanceType_Plugin value)  plugin,required TResult Function( UiGeneratorInstanceType_Sampler value)  sampler,}){
final _that = this;
switch (_that) {
case UiGeneratorInstanceType_Plugin():
return plugin(_that);case UiGeneratorInstanceType_Sampler():
return sampler(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiGeneratorInstanceType_Plugin value)?  plugin,TResult? Function( UiGeneratorInstanceType_Sampler value)?  sampler,}){
final _that = this;
switch (_that) {
case UiGeneratorInstanceType_Plugin() when plugin != null:
return plugin(_that);case UiGeneratorInstanceType_Sampler() when sampler != null:
return sampler(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( UiPluginInstance field0)?  plugin,TResult Function( int assetId,  int rootNote)?  sampler,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiGeneratorInstanceType_Plugin() when plugin != null:
return plugin(_that.field0);case UiGeneratorInstanceType_Sampler() when sampler != null:
return sampler(_that.assetId,_that.rootNote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( UiPluginInstance field0)  plugin,required TResult Function( int assetId,  int rootNote)  sampler,}) {final _that = this;
switch (_that) {
case UiGeneratorInstanceType_Plugin():
return plugin(_that.field0);case UiGeneratorInstanceType_Sampler():
return sampler(_that.assetId,_that.rootNote);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( UiPluginInstance field0)?  plugin,TResult? Function( int assetId,  int rootNote)?  sampler,}) {final _that = this;
switch (_that) {
case UiGeneratorInstanceType_Plugin() when plugin != null:
return plugin(_that.field0);case UiGeneratorInstanceType_Sampler() when sampler != null:
return sampler(_that.assetId,_that.rootNote);case _:
  return null;

}
}

}

/// @nodoc


class UiGeneratorInstanceType_Plugin extends UiGeneratorInstanceType {
  const UiGeneratorInstanceType_Plugin(this.field0): super._();
  

 final  UiPluginInstance field0;

/// Create a copy of UiGeneratorInstanceType
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiGeneratorInstanceType_PluginCopyWith<UiGeneratorInstanceType_Plugin> get copyWith => _$UiGeneratorInstanceType_PluginCopyWithImpl<UiGeneratorInstanceType_Plugin>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiGeneratorInstanceType_Plugin&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiGeneratorInstanceType.plugin(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiGeneratorInstanceType_PluginCopyWith<$Res> implements $UiGeneratorInstanceTypeCopyWith<$Res> {
  factory $UiGeneratorInstanceType_PluginCopyWith(UiGeneratorInstanceType_Plugin value, $Res Function(UiGeneratorInstanceType_Plugin) _then) = _$UiGeneratorInstanceType_PluginCopyWithImpl;
@useResult
$Res call({
 UiPluginInstance field0
});


$UiPluginInstanceCopyWith<$Res> get field0;

}
/// @nodoc
class _$UiGeneratorInstanceType_PluginCopyWithImpl<$Res>
    implements $UiGeneratorInstanceType_PluginCopyWith<$Res> {
  _$UiGeneratorInstanceType_PluginCopyWithImpl(this._self, this._then);

  final UiGeneratorInstanceType_Plugin _self;
  final $Res Function(UiGeneratorInstanceType_Plugin) _then;

/// Create a copy of UiGeneratorInstanceType
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiGeneratorInstanceType_Plugin(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as UiPluginInstance,
  ));
}

/// Create a copy of UiGeneratorInstanceType
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiPluginInstanceCopyWith<$Res> get field0 {
  
  return $UiPluginInstanceCopyWith<$Res>(_self.field0, (value) {
    return _then(_self.copyWith(field0: value));
  });
}
}

/// @nodoc


class UiGeneratorInstanceType_Sampler extends UiGeneratorInstanceType {
  const UiGeneratorInstanceType_Sampler({required this.assetId, required this.rootNote}): super._();
  

 final  int assetId;
 final  int rootNote;

/// Create a copy of UiGeneratorInstanceType
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiGeneratorInstanceType_SamplerCopyWith<UiGeneratorInstanceType_Sampler> get copyWith => _$UiGeneratorInstanceType_SamplerCopyWithImpl<UiGeneratorInstanceType_Sampler>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiGeneratorInstanceType_Sampler&&(identical(other.assetId, assetId) || other.assetId == assetId)&&(identical(other.rootNote, rootNote) || other.rootNote == rootNote));
}


@override
int get hashCode => Object.hash(runtimeType,assetId,rootNote);

@override
String toString() {
  return 'UiGeneratorInstanceType.sampler(assetId: $assetId, rootNote: $rootNote)';
}


}

/// @nodoc
abstract mixin class $UiGeneratorInstanceType_SamplerCopyWith<$Res> implements $UiGeneratorInstanceTypeCopyWith<$Res> {
  factory $UiGeneratorInstanceType_SamplerCopyWith(UiGeneratorInstanceType_Sampler value, $Res Function(UiGeneratorInstanceType_Sampler) _then) = _$UiGeneratorInstanceType_SamplerCopyWithImpl;
@useResult
$Res call({
 int assetId, int rootNote
});




}
/// @nodoc
class _$UiGeneratorInstanceType_SamplerCopyWithImpl<$Res>
    implements $UiGeneratorInstanceType_SamplerCopyWith<$Res> {
  _$UiGeneratorInstanceType_SamplerCopyWithImpl(this._self, this._then);

  final UiGeneratorInstanceType_Sampler _self;
  final $Res Function(UiGeneratorInstanceType_Sampler) _then;

/// Create a copy of UiGeneratorInstanceType
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? assetId = null,Object? rootNote = null,}) {
  return _then(UiGeneratorInstanceType_Sampler(
assetId: null == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as int,rootNote: null == rootNote ? _self.rootNote : rootNote // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiPluginInstance {

 int get registryId; String get name; bool get bypass;
/// Create a copy of UiPluginInstance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginInstanceCopyWith<UiPluginInstance> get copyWith => _$UiPluginInstanceCopyWithImpl<UiPluginInstance>(this as UiPluginInstance, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginInstance&&(identical(other.registryId, registryId) || other.registryId == registryId)&&(identical(other.name, name) || other.name == name)&&(identical(other.bypass, bypass) || other.bypass == bypass));
}


@override
int get hashCode => Object.hash(runtimeType,registryId,name,bypass);

@override
String toString() {
  return 'UiPluginInstance(registryId: $registryId, name: $name, bypass: $bypass)';
}


}

/// @nodoc
abstract mixin class $UiPluginInstanceCopyWith<$Res>  {
  factory $UiPluginInstanceCopyWith(UiPluginInstance value, $Res Function(UiPluginInstance) _then) = _$UiPluginInstanceCopyWithImpl;
@useResult
$Res call({
 int registryId, String name, bool bypass
});




}
/// @nodoc
class _$UiPluginInstanceCopyWithImpl<$Res>
    implements $UiPluginInstanceCopyWith<$Res> {
  _$UiPluginInstanceCopyWithImpl(this._self, this._then);

  final UiPluginInstance _self;
  final $Res Function(UiPluginInstance) _then;

/// Create a copy of UiPluginInstance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? registryId = null,Object? name = null,Object? bypass = null,}) {
  return _then(_self.copyWith(
registryId: null == registryId ? _self.registryId : registryId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bypass: null == bypass ? _self.bypass : bypass // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UiPluginInstance].
extension UiPluginInstancePatterns on UiPluginInstance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiPluginInstance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiPluginInstance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiPluginInstance value)  $default,){
final _that = this;
switch (_that) {
case _UiPluginInstance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiPluginInstance value)?  $default,){
final _that = this;
switch (_that) {
case _UiPluginInstance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int registryId,  String name,  bool bypass)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiPluginInstance() when $default != null:
return $default(_that.registryId,_that.name,_that.bypass);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int registryId,  String name,  bool bypass)  $default,) {final _that = this;
switch (_that) {
case _UiPluginInstance():
return $default(_that.registryId,_that.name,_that.bypass);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int registryId,  String name,  bool bypass)?  $default,) {final _that = this;
switch (_that) {
case _UiPluginInstance() when $default != null:
return $default(_that.registryId,_that.name,_that.bypass);case _:
  return null;

}
}

}

/// @nodoc


class _UiPluginInstance implements UiPluginInstance {
  const _UiPluginInstance({required this.registryId, required this.name, required this.bypass});
  

@override final  int registryId;
@override final  String name;
@override final  bool bypass;

/// Create a copy of UiPluginInstance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiPluginInstanceCopyWith<_UiPluginInstance> get copyWith => __$UiPluginInstanceCopyWithImpl<_UiPluginInstance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiPluginInstance&&(identical(other.registryId, registryId) || other.registryId == registryId)&&(identical(other.name, name) || other.name == name)&&(identical(other.bypass, bypass) || other.bypass == bypass));
}


@override
int get hashCode => Object.hash(runtimeType,registryId,name,bypass);

@override
String toString() {
  return 'UiPluginInstance(registryId: $registryId, name: $name, bypass: $bypass)';
}


}

/// @nodoc
abstract mixin class _$UiPluginInstanceCopyWith<$Res> implements $UiPluginInstanceCopyWith<$Res> {
  factory _$UiPluginInstanceCopyWith(_UiPluginInstance value, $Res Function(_UiPluginInstance) _then) = __$UiPluginInstanceCopyWithImpl;
@override @useResult
$Res call({
 int registryId, String name, bool bypass
});




}
/// @nodoc
class __$UiPluginInstanceCopyWithImpl<$Res>
    implements _$UiPluginInstanceCopyWith<$Res> {
  __$UiPluginInstanceCopyWithImpl(this._self, this._then);

  final _UiPluginInstance _self;
  final $Res Function(_UiPluginInstance) _then;

/// Create a copy of UiPluginInstance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? registryId = null,Object? name = null,Object? bypass = null,}) {
  return _then(_UiPluginInstance(
registryId: null == registryId ? _self.registryId : registryId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bypass: null == bypass ? _self.bypass : bypass // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$UiProjectMetadata {

 String get name; String get author; String get version; String get createdAt;
/// Create a copy of UiProjectMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiProjectMetadataCopyWith<UiProjectMetadata> get copyWith => _$UiProjectMetadataCopyWithImpl<UiProjectMetadata>(this as UiProjectMetadata, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiProjectMetadata&&(identical(other.name, name) || other.name == name)&&(identical(other.author, author) || other.author == author)&&(identical(other.version, version) || other.version == version)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,name,author,version,createdAt);

@override
String toString() {
  return 'UiProjectMetadata(name: $name, author: $author, version: $version, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $UiProjectMetadataCopyWith<$Res>  {
  factory $UiProjectMetadataCopyWith(UiProjectMetadata value, $Res Function(UiProjectMetadata) _then) = _$UiProjectMetadataCopyWithImpl;
@useResult
$Res call({
 String name, String author, String version, String createdAt
});




}
/// @nodoc
class _$UiProjectMetadataCopyWithImpl<$Res>
    implements $UiProjectMetadataCopyWith<$Res> {
  _$UiProjectMetadataCopyWithImpl(this._self, this._then);

  final UiProjectMetadata _self;
  final $Res Function(UiProjectMetadata) _then;

/// Create a copy of UiProjectMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? author = null,Object? version = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiProjectMetadata].
extension UiProjectMetadataPatterns on UiProjectMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiProjectMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiProjectMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiProjectMetadata value)  $default,){
final _that = this;
switch (_that) {
case _UiProjectMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiProjectMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _UiProjectMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String author,  String version,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiProjectMetadata() when $default != null:
return $default(_that.name,_that.author,_that.version,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String author,  String version,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _UiProjectMetadata():
return $default(_that.name,_that.author,_that.version,_that.createdAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String author,  String version,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _UiProjectMetadata() when $default != null:
return $default(_that.name,_that.author,_that.version,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _UiProjectMetadata extends UiProjectMetadata {
  const _UiProjectMetadata({required this.name, required this.author, required this.version, required this.createdAt}): super._();
  

@override final  String name;
@override final  String author;
@override final  String version;
@override final  String createdAt;

/// Create a copy of UiProjectMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiProjectMetadataCopyWith<_UiProjectMetadata> get copyWith => __$UiProjectMetadataCopyWithImpl<_UiProjectMetadata>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiProjectMetadata&&(identical(other.name, name) || other.name == name)&&(identical(other.author, author) || other.author == author)&&(identical(other.version, version) || other.version == version)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,name,author,version,createdAt);

@override
String toString() {
  return 'UiProjectMetadata(name: $name, author: $author, version: $version, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$UiProjectMetadataCopyWith<$Res> implements $UiProjectMetadataCopyWith<$Res> {
  factory _$UiProjectMetadataCopyWith(_UiProjectMetadata value, $Res Function(_UiProjectMetadata) _then) = __$UiProjectMetadataCopyWithImpl;
@override @useResult
$Res call({
 String name, String author, String version, String createdAt
});




}
/// @nodoc
class __$UiProjectMetadataCopyWithImpl<$Res>
    implements _$UiProjectMetadataCopyWith<$Res> {
  __$UiProjectMetadataCopyWithImpl(this._self, this._then);

  final _UiProjectMetadata _self;
  final $Res Function(_UiProjectMetadata) _then;

/// Create a copy of UiProjectMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? author = null,Object? version = null,Object? createdAt = null,}) {
  return _then(_UiProjectMetadata(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiTrack {

 int get id; String get name; String get color; UiTrackType get trackType; List<UiClip> get clips; int? get generatorId; int get orderIdx;
/// Create a copy of UiTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiTrackCopyWith<UiTrack> get copyWith => _$UiTrackCopyWithImpl<UiTrack>(this as UiTrack, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiTrack&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.trackType, trackType) || other.trackType == trackType)&&const DeepCollectionEquality().equals(other.clips, clips)&&(identical(other.generatorId, generatorId) || other.generatorId == generatorId)&&(identical(other.orderIdx, orderIdx) || other.orderIdx == orderIdx));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,color,trackType,const DeepCollectionEquality().hash(clips),generatorId,orderIdx);

@override
String toString() {
  return 'UiTrack(id: $id, name: $name, color: $color, trackType: $trackType, clips: $clips, generatorId: $generatorId, orderIdx: $orderIdx)';
}


}

/// @nodoc
abstract mixin class $UiTrackCopyWith<$Res>  {
  factory $UiTrackCopyWith(UiTrack value, $Res Function(UiTrack) _then) = _$UiTrackCopyWithImpl;
@useResult
$Res call({
 int id, String name, String color, UiTrackType trackType, List<UiClip> clips, int? generatorId, int orderIdx
});




}
/// @nodoc
class _$UiTrackCopyWithImpl<$Res>
    implements $UiTrackCopyWith<$Res> {
  _$UiTrackCopyWithImpl(this._self, this._then);

  final UiTrack _self;
  final $Res Function(UiTrack) _then;

/// Create a copy of UiTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = null,Object? trackType = null,Object? clips = null,Object? generatorId = freezed,Object? orderIdx = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as UiTrackType,clips: null == clips ? _self.clips : clips // ignore: cast_nullable_to_non_nullable
as List<UiClip>,generatorId: freezed == generatorId ? _self.generatorId : generatorId // ignore: cast_nullable_to_non_nullable
as int?,orderIdx: null == orderIdx ? _self.orderIdx : orderIdx // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiTrack].
extension UiTrackPatterns on UiTrack {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiTrack() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiTrack value)  $default,){
final _that = this;
switch (_that) {
case _UiTrack():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiTrack value)?  $default,){
final _that = this;
switch (_that) {
case _UiTrack() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String color,  UiTrackType trackType,  List<UiClip> clips,  int? generatorId,  int orderIdx)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiTrack() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.trackType,_that.clips,_that.generatorId,_that.orderIdx);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String color,  UiTrackType trackType,  List<UiClip> clips,  int? generatorId,  int orderIdx)  $default,) {final _that = this;
switch (_that) {
case _UiTrack():
return $default(_that.id,_that.name,_that.color,_that.trackType,_that.clips,_that.generatorId,_that.orderIdx);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String color,  UiTrackType trackType,  List<UiClip> clips,  int? generatorId,  int orderIdx)?  $default,) {final _that = this;
switch (_that) {
case _UiTrack() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.trackType,_that.clips,_that.generatorId,_that.orderIdx);case _:
  return null;

}
}

}

/// @nodoc


class _UiTrack implements UiTrack {
  const _UiTrack({required this.id, required this.name, required this.color, required this.trackType, required final  List<UiClip> clips, this.generatorId, required this.orderIdx}): _clips = clips;
  

@override final  int id;
@override final  String name;
@override final  String color;
@override final  UiTrackType trackType;
 final  List<UiClip> _clips;
@override List<UiClip> get clips {
  if (_clips is EqualUnmodifiableListView) return _clips;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clips);
}

@override final  int? generatorId;
@override final  int orderIdx;

/// Create a copy of UiTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiTrackCopyWith<_UiTrack> get copyWith => __$UiTrackCopyWithImpl<_UiTrack>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiTrack&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.trackType, trackType) || other.trackType == trackType)&&const DeepCollectionEquality().equals(other._clips, _clips)&&(identical(other.generatorId, generatorId) || other.generatorId == generatorId)&&(identical(other.orderIdx, orderIdx) || other.orderIdx == orderIdx));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,color,trackType,const DeepCollectionEquality().hash(_clips),generatorId,orderIdx);

@override
String toString() {
  return 'UiTrack(id: $id, name: $name, color: $color, trackType: $trackType, clips: $clips, generatorId: $generatorId, orderIdx: $orderIdx)';
}


}

/// @nodoc
abstract mixin class _$UiTrackCopyWith<$Res> implements $UiTrackCopyWith<$Res> {
  factory _$UiTrackCopyWith(_UiTrack value, $Res Function(_UiTrack) _then) = __$UiTrackCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String color, UiTrackType trackType, List<UiClip> clips, int? generatorId, int orderIdx
});




}
/// @nodoc
class __$UiTrackCopyWithImpl<$Res>
    implements _$UiTrackCopyWith<$Res> {
  __$UiTrackCopyWithImpl(this._self, this._then);

  final _UiTrack _self;
  final $Res Function(_UiTrack) _then;

/// Create a copy of UiTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = null,Object? trackType = null,Object? clips = null,Object? generatorId = freezed,Object? orderIdx = null,}) {
  return _then(_UiTrack(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as UiTrackType,clips: null == clips ? _self._clips : clips // ignore: cast_nullable_to_non_nullable
as List<UiClip>,generatorId: freezed == generatorId ? _self.generatorId : generatorId // ignore: cast_nullable_to_non_nullable
as int?,orderIdx: null == orderIdx ? _self.orderIdx : orderIdx // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiTransportState {

 double get bpm; (int, int) get timeSignature;
/// Create a copy of UiTransportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiTransportStateCopyWith<UiTransportState> get copyWith => _$UiTransportStateCopyWithImpl<UiTransportState>(this as UiTransportState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiTransportState&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.timeSignature, timeSignature) || other.timeSignature == timeSignature));
}


@override
int get hashCode => Object.hash(runtimeType,bpm,timeSignature);

@override
String toString() {
  return 'UiTransportState(bpm: $bpm, timeSignature: $timeSignature)';
}


}

/// @nodoc
abstract mixin class $UiTransportStateCopyWith<$Res>  {
  factory $UiTransportStateCopyWith(UiTransportState value, $Res Function(UiTransportState) _then) = _$UiTransportStateCopyWithImpl;
@useResult
$Res call({
 double bpm, (int, int) timeSignature
});




}
/// @nodoc
class _$UiTransportStateCopyWithImpl<$Res>
    implements $UiTransportStateCopyWith<$Res> {
  _$UiTransportStateCopyWithImpl(this._self, this._then);

  final UiTransportState _self;
  final $Res Function(UiTransportState) _then;

/// Create a copy of UiTransportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bpm = null,Object? timeSignature = null,}) {
  return _then(_self.copyWith(
bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double,timeSignature: null == timeSignature ? _self.timeSignature : timeSignature // ignore: cast_nullable_to_non_nullable
as (int, int),
  ));
}

}


/// Adds pattern-matching-related methods to [UiTransportState].
extension UiTransportStatePatterns on UiTransportState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiTransportState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiTransportState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiTransportState value)  $default,){
final _that = this;
switch (_that) {
case _UiTransportState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiTransportState value)?  $default,){
final _that = this;
switch (_that) {
case _UiTransportState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double bpm,  (int, int) timeSignature)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiTransportState() when $default != null:
return $default(_that.bpm,_that.timeSignature);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double bpm,  (int, int) timeSignature)  $default,) {final _that = this;
switch (_that) {
case _UiTransportState():
return $default(_that.bpm,_that.timeSignature);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double bpm,  (int, int) timeSignature)?  $default,) {final _that = this;
switch (_that) {
case _UiTransportState() when $default != null:
return $default(_that.bpm,_that.timeSignature);case _:
  return null;

}
}

}

/// @nodoc


class _UiTransportState extends UiTransportState {
  const _UiTransportState({required this.bpm, required this.timeSignature}): super._();
  

@override final  double bpm;
@override final  (int, int) timeSignature;

/// Create a copy of UiTransportState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiTransportStateCopyWith<_UiTransportState> get copyWith => __$UiTransportStateCopyWithImpl<_UiTransportState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiTransportState&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.timeSignature, timeSignature) || other.timeSignature == timeSignature));
}


@override
int get hashCode => Object.hash(runtimeType,bpm,timeSignature);

@override
String toString() {
  return 'UiTransportState(bpm: $bpm, timeSignature: $timeSignature)';
}


}

/// @nodoc
abstract mixin class _$UiTransportStateCopyWith<$Res> implements $UiTransportStateCopyWith<$Res> {
  factory _$UiTransportStateCopyWith(_UiTransportState value, $Res Function(_UiTransportState) _then) = __$UiTransportStateCopyWithImpl;
@override @useResult
$Res call({
 double bpm, (int, int) timeSignature
});




}
/// @nodoc
class __$UiTransportStateCopyWithImpl<$Res>
    implements _$UiTransportStateCopyWith<$Res> {
  __$UiTransportStateCopyWithImpl(this._self, this._then);

  final _UiTransportState _self;
  final $Res Function(_UiTransportState) _then;

/// Create a copy of UiTransportState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bpm = null,Object? timeSignature = null,}) {
  return _then(_UiTransportState(
bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double,timeSignature: null == timeSignature ? _self.timeSignature : timeSignature // ignore: cast_nullable_to_non_nullable
as (int, int),
  ));
}


}

// dart format on
