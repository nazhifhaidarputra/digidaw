// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiTransportFeedback {

 int get samples; int get ticks; int get beat; int get bar; double get tempo; int get sampleRate; bool get isPlaying; bool get isLooping; bool get isRecording; bool get isPatternPlaying; bool get isPatternMode; int get patternSamples; int get patternTicks; int get patternBeat; int get patternBar;
/// Create a copy of UiTransportFeedback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiTransportFeedbackCopyWith<UiTransportFeedback> get copyWith => _$UiTransportFeedbackCopyWithImpl<UiTransportFeedback>(this as UiTransportFeedback, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiTransportFeedback&&(identical(other.samples, samples) || other.samples == samples)&&(identical(other.ticks, ticks) || other.ticks == ticks)&&(identical(other.beat, beat) || other.beat == beat)&&(identical(other.bar, bar) || other.bar == bar)&&(identical(other.tempo, tempo) || other.tempo == tempo)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.isPlaying, isPlaying) || other.isPlaying == isPlaying)&&(identical(other.isLooping, isLooping) || other.isLooping == isLooping)&&(identical(other.isRecording, isRecording) || other.isRecording == isRecording)&&(identical(other.isPatternPlaying, isPatternPlaying) || other.isPatternPlaying == isPatternPlaying)&&(identical(other.isPatternMode, isPatternMode) || other.isPatternMode == isPatternMode)&&(identical(other.patternSamples, patternSamples) || other.patternSamples == patternSamples)&&(identical(other.patternTicks, patternTicks) || other.patternTicks == patternTicks)&&(identical(other.patternBeat, patternBeat) || other.patternBeat == patternBeat)&&(identical(other.patternBar, patternBar) || other.patternBar == patternBar));
}


@override
int get hashCode => Object.hash(runtimeType,samples,ticks,beat,bar,tempo,sampleRate,isPlaying,isLooping,isRecording,isPatternPlaying,isPatternMode,patternSamples,patternTicks,patternBeat,patternBar);

@override
String toString() {
  return 'UiTransportFeedback(samples: $samples, ticks: $ticks, beat: $beat, bar: $bar, tempo: $tempo, sampleRate: $sampleRate, isPlaying: $isPlaying, isLooping: $isLooping, isRecording: $isRecording, isPatternPlaying: $isPatternPlaying, isPatternMode: $isPatternMode, patternSamples: $patternSamples, patternTicks: $patternTicks, patternBeat: $patternBeat, patternBar: $patternBar)';
}


}

/// @nodoc
abstract mixin class $UiTransportFeedbackCopyWith<$Res>  {
  factory $UiTransportFeedbackCopyWith(UiTransportFeedback value, $Res Function(UiTransportFeedback) _then) = _$UiTransportFeedbackCopyWithImpl;
@useResult
$Res call({
 int samples, int ticks, int beat, int bar, double tempo, int sampleRate, bool isPlaying, bool isLooping, bool isRecording, bool isPatternPlaying, bool isPatternMode, int patternSamples, int patternTicks, int patternBeat, int patternBar
});




}
/// @nodoc
class _$UiTransportFeedbackCopyWithImpl<$Res>
    implements $UiTransportFeedbackCopyWith<$Res> {
  _$UiTransportFeedbackCopyWithImpl(this._self, this._then);

  final UiTransportFeedback _self;
  final $Res Function(UiTransportFeedback) _then;

/// Create a copy of UiTransportFeedback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? samples = null,Object? ticks = null,Object? beat = null,Object? bar = null,Object? tempo = null,Object? sampleRate = null,Object? isPlaying = null,Object? isLooping = null,Object? isRecording = null,Object? isPatternPlaying = null,Object? isPatternMode = null,Object? patternSamples = null,Object? patternTicks = null,Object? patternBeat = null,Object? patternBar = null,}) {
  return _then(_self.copyWith(
samples: null == samples ? _self.samples : samples // ignore: cast_nullable_to_non_nullable
as int,ticks: null == ticks ? _self.ticks : ticks // ignore: cast_nullable_to_non_nullable
as int,beat: null == beat ? _self.beat : beat // ignore: cast_nullable_to_non_nullable
as int,bar: null == bar ? _self.bar : bar // ignore: cast_nullable_to_non_nullable
as int,tempo: null == tempo ? _self.tempo : tempo // ignore: cast_nullable_to_non_nullable
as double,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,isPlaying: null == isPlaying ? _self.isPlaying : isPlaying // ignore: cast_nullable_to_non_nullable
as bool,isLooping: null == isLooping ? _self.isLooping : isLooping // ignore: cast_nullable_to_non_nullable
as bool,isRecording: null == isRecording ? _self.isRecording : isRecording // ignore: cast_nullable_to_non_nullable
as bool,isPatternPlaying: null == isPatternPlaying ? _self.isPatternPlaying : isPatternPlaying // ignore: cast_nullable_to_non_nullable
as bool,isPatternMode: null == isPatternMode ? _self.isPatternMode : isPatternMode // ignore: cast_nullable_to_non_nullable
as bool,patternSamples: null == patternSamples ? _self.patternSamples : patternSamples // ignore: cast_nullable_to_non_nullable
as int,patternTicks: null == patternTicks ? _self.patternTicks : patternTicks // ignore: cast_nullable_to_non_nullable
as int,patternBeat: null == patternBeat ? _self.patternBeat : patternBeat // ignore: cast_nullable_to_non_nullable
as int,patternBar: null == patternBar ? _self.patternBar : patternBar // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiTransportFeedback].
extension UiTransportFeedbackPatterns on UiTransportFeedback {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiTransportFeedback value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiTransportFeedback() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiTransportFeedback value)  $default,){
final _that = this;
switch (_that) {
case _UiTransportFeedback():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiTransportFeedback value)?  $default,){
final _that = this;
switch (_that) {
case _UiTransportFeedback() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int samples,  int ticks,  int beat,  int bar,  double tempo,  int sampleRate,  bool isPlaying,  bool isLooping,  bool isRecording,  bool isPatternPlaying,  bool isPatternMode,  int patternSamples,  int patternTicks,  int patternBeat,  int patternBar)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiTransportFeedback() when $default != null:
return $default(_that.samples,_that.ticks,_that.beat,_that.bar,_that.tempo,_that.sampleRate,_that.isPlaying,_that.isLooping,_that.isRecording,_that.isPatternPlaying,_that.isPatternMode,_that.patternSamples,_that.patternTicks,_that.patternBeat,_that.patternBar);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int samples,  int ticks,  int beat,  int bar,  double tempo,  int sampleRate,  bool isPlaying,  bool isLooping,  bool isRecording,  bool isPatternPlaying,  bool isPatternMode,  int patternSamples,  int patternTicks,  int patternBeat,  int patternBar)  $default,) {final _that = this;
switch (_that) {
case _UiTransportFeedback():
return $default(_that.samples,_that.ticks,_that.beat,_that.bar,_that.tempo,_that.sampleRate,_that.isPlaying,_that.isLooping,_that.isRecording,_that.isPatternPlaying,_that.isPatternMode,_that.patternSamples,_that.patternTicks,_that.patternBeat,_that.patternBar);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int samples,  int ticks,  int beat,  int bar,  double tempo,  int sampleRate,  bool isPlaying,  bool isLooping,  bool isRecording,  bool isPatternPlaying,  bool isPatternMode,  int patternSamples,  int patternTicks,  int patternBeat,  int patternBar)?  $default,) {final _that = this;
switch (_that) {
case _UiTransportFeedback() when $default != null:
return $default(_that.samples,_that.ticks,_that.beat,_that.bar,_that.tempo,_that.sampleRate,_that.isPlaying,_that.isLooping,_that.isRecording,_that.isPatternPlaying,_that.isPatternMode,_that.patternSamples,_that.patternTicks,_that.patternBeat,_that.patternBar);case _:
  return null;

}
}

}

/// @nodoc


class _UiTransportFeedback implements UiTransportFeedback {
  const _UiTransportFeedback({required this.samples, required this.ticks, required this.beat, required this.bar, required this.tempo, required this.sampleRate, required this.isPlaying, required this.isLooping, required this.isRecording, required this.isPatternPlaying, required this.isPatternMode, required this.patternSamples, required this.patternTicks, required this.patternBeat, required this.patternBar});
  

@override final  int samples;
@override final  int ticks;
@override final  int beat;
@override final  int bar;
@override final  double tempo;
@override final  int sampleRate;
@override final  bool isPlaying;
@override final  bool isLooping;
@override final  bool isRecording;
@override final  bool isPatternPlaying;
@override final  bool isPatternMode;
@override final  int patternSamples;
@override final  int patternTicks;
@override final  int patternBeat;
@override final  int patternBar;

/// Create a copy of UiTransportFeedback
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiTransportFeedbackCopyWith<_UiTransportFeedback> get copyWith => __$UiTransportFeedbackCopyWithImpl<_UiTransportFeedback>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiTransportFeedback&&(identical(other.samples, samples) || other.samples == samples)&&(identical(other.ticks, ticks) || other.ticks == ticks)&&(identical(other.beat, beat) || other.beat == beat)&&(identical(other.bar, bar) || other.bar == bar)&&(identical(other.tempo, tempo) || other.tempo == tempo)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.isPlaying, isPlaying) || other.isPlaying == isPlaying)&&(identical(other.isLooping, isLooping) || other.isLooping == isLooping)&&(identical(other.isRecording, isRecording) || other.isRecording == isRecording)&&(identical(other.isPatternPlaying, isPatternPlaying) || other.isPatternPlaying == isPatternPlaying)&&(identical(other.isPatternMode, isPatternMode) || other.isPatternMode == isPatternMode)&&(identical(other.patternSamples, patternSamples) || other.patternSamples == patternSamples)&&(identical(other.patternTicks, patternTicks) || other.patternTicks == patternTicks)&&(identical(other.patternBeat, patternBeat) || other.patternBeat == patternBeat)&&(identical(other.patternBar, patternBar) || other.patternBar == patternBar));
}


@override
int get hashCode => Object.hash(runtimeType,samples,ticks,beat,bar,tempo,sampleRate,isPlaying,isLooping,isRecording,isPatternPlaying,isPatternMode,patternSamples,patternTicks,patternBeat,patternBar);

@override
String toString() {
  return 'UiTransportFeedback(samples: $samples, ticks: $ticks, beat: $beat, bar: $bar, tempo: $tempo, sampleRate: $sampleRate, isPlaying: $isPlaying, isLooping: $isLooping, isRecording: $isRecording, isPatternPlaying: $isPatternPlaying, isPatternMode: $isPatternMode, patternSamples: $patternSamples, patternTicks: $patternTicks, patternBeat: $patternBeat, patternBar: $patternBar)';
}


}

/// @nodoc
abstract mixin class _$UiTransportFeedbackCopyWith<$Res> implements $UiTransportFeedbackCopyWith<$Res> {
  factory _$UiTransportFeedbackCopyWith(_UiTransportFeedback value, $Res Function(_UiTransportFeedback) _then) = __$UiTransportFeedbackCopyWithImpl;
@override @useResult
$Res call({
 int samples, int ticks, int beat, int bar, double tempo, int sampleRate, bool isPlaying, bool isLooping, bool isRecording, bool isPatternPlaying, bool isPatternMode, int patternSamples, int patternTicks, int patternBeat, int patternBar
});




}
/// @nodoc
class __$UiTransportFeedbackCopyWithImpl<$Res>
    implements _$UiTransportFeedbackCopyWith<$Res> {
  __$UiTransportFeedbackCopyWithImpl(this._self, this._then);

  final _UiTransportFeedback _self;
  final $Res Function(_UiTransportFeedback) _then;

/// Create a copy of UiTransportFeedback
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? samples = null,Object? ticks = null,Object? beat = null,Object? bar = null,Object? tempo = null,Object? sampleRate = null,Object? isPlaying = null,Object? isLooping = null,Object? isRecording = null,Object? isPatternPlaying = null,Object? isPatternMode = null,Object? patternSamples = null,Object? patternTicks = null,Object? patternBeat = null,Object? patternBar = null,}) {
  return _then(_UiTransportFeedback(
samples: null == samples ? _self.samples : samples // ignore: cast_nullable_to_non_nullable
as int,ticks: null == ticks ? _self.ticks : ticks // ignore: cast_nullable_to_non_nullable
as int,beat: null == beat ? _self.beat : beat // ignore: cast_nullable_to_non_nullable
as int,bar: null == bar ? _self.bar : bar // ignore: cast_nullable_to_non_nullable
as int,tempo: null == tempo ? _self.tempo : tempo // ignore: cast_nullable_to_non_nullable
as double,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,isPlaying: null == isPlaying ? _self.isPlaying : isPlaying // ignore: cast_nullable_to_non_nullable
as bool,isLooping: null == isLooping ? _self.isLooping : isLooping // ignore: cast_nullable_to_non_nullable
as bool,isRecording: null == isRecording ? _self.isRecording : isRecording // ignore: cast_nullable_to_non_nullable
as bool,isPatternPlaying: null == isPatternPlaying ? _self.isPatternPlaying : isPatternPlaying // ignore: cast_nullable_to_non_nullable
as bool,isPatternMode: null == isPatternMode ? _self.isPatternMode : isPatternMode // ignore: cast_nullable_to_non_nullable
as bool,patternSamples: null == patternSamples ? _self.patternSamples : patternSamples // ignore: cast_nullable_to_non_nullable
as int,patternTicks: null == patternTicks ? _self.patternTicks : patternTicks // ignore: cast_nullable_to_non_nullable
as int,patternBeat: null == patternBeat ? _self.patternBeat : patternBeat // ignore: cast_nullable_to_non_nullable
as int,patternBar: null == patternBar ? _self.patternBar : patternBar // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
