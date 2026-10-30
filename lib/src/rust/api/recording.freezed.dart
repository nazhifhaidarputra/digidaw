// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recording.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiRecordingProgress {

 int get trackId; int? get startSamples; int get frames; int get sampleRate; int get peakOffset; Float32List get peaks; bool get ended;
/// Create a copy of UiRecordingProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiRecordingProgressCopyWith<UiRecordingProgress> get copyWith => _$UiRecordingProgressCopyWithImpl<UiRecordingProgress>(this as UiRecordingProgress, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRecordingProgress&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.startSamples, startSamples) || other.startSamples == startSamples)&&(identical(other.frames, frames) || other.frames == frames)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.peakOffset, peakOffset) || other.peakOffset == peakOffset)&&const DeepCollectionEquality().equals(other.peaks, peaks)&&(identical(other.ended, ended) || other.ended == ended));
}


@override
int get hashCode => Object.hash(runtimeType,trackId,startSamples,frames,sampleRate,peakOffset,const DeepCollectionEquality().hash(peaks),ended);

@override
String toString() {
  return 'UiRecordingProgress(trackId: $trackId, startSamples: $startSamples, frames: $frames, sampleRate: $sampleRate, peakOffset: $peakOffset, peaks: $peaks, ended: $ended)';
}


}

/// @nodoc
abstract mixin class $UiRecordingProgressCopyWith<$Res>  {
  factory $UiRecordingProgressCopyWith(UiRecordingProgress value, $Res Function(UiRecordingProgress) _then) = _$UiRecordingProgressCopyWithImpl;
@useResult
$Res call({
 int trackId, int? startSamples, int frames, int sampleRate, int peakOffset, Float32List peaks, bool ended
});




}
/// @nodoc
class _$UiRecordingProgressCopyWithImpl<$Res>
    implements $UiRecordingProgressCopyWith<$Res> {
  _$UiRecordingProgressCopyWithImpl(this._self, this._then);

  final UiRecordingProgress _self;
  final $Res Function(UiRecordingProgress) _then;

/// Create a copy of UiRecordingProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trackId = null,Object? startSamples = freezed,Object? frames = null,Object? sampleRate = null,Object? peakOffset = null,Object? peaks = null,Object? ended = null,}) {
  return _then(_self.copyWith(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,startSamples: freezed == startSamples ? _self.startSamples : startSamples // ignore: cast_nullable_to_non_nullable
as int?,frames: null == frames ? _self.frames : frames // ignore: cast_nullable_to_non_nullable
as int,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,peakOffset: null == peakOffset ? _self.peakOffset : peakOffset // ignore: cast_nullable_to_non_nullable
as int,peaks: null == peaks ? _self.peaks : peaks // ignore: cast_nullable_to_non_nullable
as Float32List,ended: null == ended ? _self.ended : ended // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UiRecordingProgress].
extension UiRecordingProgressPatterns on UiRecordingProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiRecordingProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiRecordingProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiRecordingProgress value)  $default,){
final _that = this;
switch (_that) {
case _UiRecordingProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiRecordingProgress value)?  $default,){
final _that = this;
switch (_that) {
case _UiRecordingProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int trackId,  int? startSamples,  int frames,  int sampleRate,  int peakOffset,  Float32List peaks,  bool ended)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiRecordingProgress() when $default != null:
return $default(_that.trackId,_that.startSamples,_that.frames,_that.sampleRate,_that.peakOffset,_that.peaks,_that.ended);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int trackId,  int? startSamples,  int frames,  int sampleRate,  int peakOffset,  Float32List peaks,  bool ended)  $default,) {final _that = this;
switch (_that) {
case _UiRecordingProgress():
return $default(_that.trackId,_that.startSamples,_that.frames,_that.sampleRate,_that.peakOffset,_that.peaks,_that.ended);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int trackId,  int? startSamples,  int frames,  int sampleRate,  int peakOffset,  Float32List peaks,  bool ended)?  $default,) {final _that = this;
switch (_that) {
case _UiRecordingProgress() when $default != null:
return $default(_that.trackId,_that.startSamples,_that.frames,_that.sampleRate,_that.peakOffset,_that.peaks,_that.ended);case _:
  return null;

}
}

}

/// @nodoc


class _UiRecordingProgress implements UiRecordingProgress {
  const _UiRecordingProgress({required this.trackId, this.startSamples, required this.frames, required this.sampleRate, required this.peakOffset, required this.peaks, required this.ended});
  

@override final  int trackId;
@override final  int? startSamples;
@override final  int frames;
@override final  int sampleRate;
@override final  int peakOffset;
@override final  Float32List peaks;
@override final  bool ended;

/// Create a copy of UiRecordingProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiRecordingProgressCopyWith<_UiRecordingProgress> get copyWith => __$UiRecordingProgressCopyWithImpl<_UiRecordingProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiRecordingProgress&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.startSamples, startSamples) || other.startSamples == startSamples)&&(identical(other.frames, frames) || other.frames == frames)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.peakOffset, peakOffset) || other.peakOffset == peakOffset)&&const DeepCollectionEquality().equals(other.peaks, peaks)&&(identical(other.ended, ended) || other.ended == ended));
}


@override
int get hashCode => Object.hash(runtimeType,trackId,startSamples,frames,sampleRate,peakOffset,const DeepCollectionEquality().hash(peaks),ended);

@override
String toString() {
  return 'UiRecordingProgress(trackId: $trackId, startSamples: $startSamples, frames: $frames, sampleRate: $sampleRate, peakOffset: $peakOffset, peaks: $peaks, ended: $ended)';
}


}

/// @nodoc
abstract mixin class _$UiRecordingProgressCopyWith<$Res> implements $UiRecordingProgressCopyWith<$Res> {
  factory _$UiRecordingProgressCopyWith(_UiRecordingProgress value, $Res Function(_UiRecordingProgress) _then) = __$UiRecordingProgressCopyWithImpl;
@override @useResult
$Res call({
 int trackId, int? startSamples, int frames, int sampleRate, int peakOffset, Float32List peaks, bool ended
});




}
/// @nodoc
class __$UiRecordingProgressCopyWithImpl<$Res>
    implements _$UiRecordingProgressCopyWith<$Res> {
  __$UiRecordingProgressCopyWithImpl(this._self, this._then);

  final _UiRecordingProgress _self;
  final $Res Function(_UiRecordingProgress) _then;

/// Create a copy of UiRecordingProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? startSamples = freezed,Object? frames = null,Object? sampleRate = null,Object? peakOffset = null,Object? peaks = null,Object? ended = null,}) {
  return _then(_UiRecordingProgress(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,startSamples: freezed == startSamples ? _self.startSamples : startSamples // ignore: cast_nullable_to_non_nullable
as int?,frames: null == frames ? _self.frames : frames // ignore: cast_nullable_to_non_nullable
as int,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,peakOffset: null == peakOffset ? _self.peakOffset : peakOffset // ignore: cast_nullable_to_non_nullable
as int,peaks: null == peaks ? _self.peaks : peaks // ignore: cast_nullable_to_non_nullable
as Float32List,ended: null == ended ? _self.ended : ended // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$UiStartedTake {

 bool get enabledInput;
/// Create a copy of UiStartedTake
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiStartedTakeCopyWith<UiStartedTake> get copyWith => _$UiStartedTakeCopyWithImpl<UiStartedTake>(this as UiStartedTake, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiStartedTake&&(identical(other.enabledInput, enabledInput) || other.enabledInput == enabledInput));
}


@override
int get hashCode => Object.hash(runtimeType,enabledInput);

@override
String toString() {
  return 'UiStartedTake(enabledInput: $enabledInput)';
}


}

/// @nodoc
abstract mixin class $UiStartedTakeCopyWith<$Res>  {
  factory $UiStartedTakeCopyWith(UiStartedTake value, $Res Function(UiStartedTake) _then) = _$UiStartedTakeCopyWithImpl;
@useResult
$Res call({
 bool enabledInput
});




}
/// @nodoc
class _$UiStartedTakeCopyWithImpl<$Res>
    implements $UiStartedTakeCopyWith<$Res> {
  _$UiStartedTakeCopyWithImpl(this._self, this._then);

  final UiStartedTake _self;
  final $Res Function(UiStartedTake) _then;

/// Create a copy of UiStartedTake
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabledInput = null,}) {
  return _then(_self.copyWith(
enabledInput: null == enabledInput ? _self.enabledInput : enabledInput // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UiStartedTake].
extension UiStartedTakePatterns on UiStartedTake {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiStartedTake value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiStartedTake() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiStartedTake value)  $default,){
final _that = this;
switch (_that) {
case _UiStartedTake():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiStartedTake value)?  $default,){
final _that = this;
switch (_that) {
case _UiStartedTake() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabledInput)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiStartedTake() when $default != null:
return $default(_that.enabledInput);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabledInput)  $default,) {final _that = this;
switch (_that) {
case _UiStartedTake():
return $default(_that.enabledInput);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabledInput)?  $default,) {final _that = this;
switch (_that) {
case _UiStartedTake() when $default != null:
return $default(_that.enabledInput);case _:
  return null;

}
}

}

/// @nodoc


class _UiStartedTake implements UiStartedTake {
  const _UiStartedTake({required this.enabledInput});
  

@override final  bool enabledInput;

/// Create a copy of UiStartedTake
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiStartedTakeCopyWith<_UiStartedTake> get copyWith => __$UiStartedTakeCopyWithImpl<_UiStartedTake>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiStartedTake&&(identical(other.enabledInput, enabledInput) || other.enabledInput == enabledInput));
}


@override
int get hashCode => Object.hash(runtimeType,enabledInput);

@override
String toString() {
  return 'UiStartedTake(enabledInput: $enabledInput)';
}


}

/// @nodoc
abstract mixin class _$UiStartedTakeCopyWith<$Res> implements $UiStartedTakeCopyWith<$Res> {
  factory _$UiStartedTakeCopyWith(_UiStartedTake value, $Res Function(_UiStartedTake) _then) = __$UiStartedTakeCopyWithImpl;
@override @useResult
$Res call({
 bool enabledInput
});




}
/// @nodoc
class __$UiStartedTakeCopyWithImpl<$Res>
    implements _$UiStartedTakeCopyWith<$Res> {
  __$UiStartedTakeCopyWithImpl(this._self, this._then);

  final _UiStartedTake _self;
  final $Res Function(_UiStartedTake) _then;

/// Create a copy of UiStartedTake
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabledInput = null,}) {
  return _then(_UiStartedTake(
enabledInput: null == enabledInput ? _self.enabledInput : enabledInput // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
