// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recording_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrackTake {

/// Song playhead, in samples, the take starts at; `null` while it waits
/// for playback.
 int? get startSamples;/// Frames recorded so far.
 int get frames; int get sampleRate;/// Lowest and highest sample of every 256 frames, in pairs.
 IList<double> get peaks;/// Whether the take is being written as a clip.
 bool get isStopping;
/// Create a copy of TrackTake
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackTakeCopyWith<TrackTake> get copyWith => _$TrackTakeCopyWithImpl<TrackTake>(this as TrackTake, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackTake&&(identical(other.startSamples, startSamples) || other.startSamples == startSamples)&&(identical(other.frames, frames) || other.frames == frames)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&const DeepCollectionEquality().equals(other.peaks, peaks)&&(identical(other.isStopping, isStopping) || other.isStopping == isStopping));
}


@override
int get hashCode => Object.hash(runtimeType,startSamples,frames,sampleRate,const DeepCollectionEquality().hash(peaks),isStopping);

@override
String toString() {
  return 'TrackTake(startSamples: $startSamples, frames: $frames, sampleRate: $sampleRate, peaks: $peaks, isStopping: $isStopping)';
}


}

/// @nodoc
abstract mixin class $TrackTakeCopyWith<$Res>  {
  factory $TrackTakeCopyWith(TrackTake value, $Res Function(TrackTake) _then) = _$TrackTakeCopyWithImpl;
@useResult
$Res call({
 int? startSamples, int frames, int sampleRate, IList<double> peaks, bool isStopping
});




}
/// @nodoc
class _$TrackTakeCopyWithImpl<$Res>
    implements $TrackTakeCopyWith<$Res> {
  _$TrackTakeCopyWithImpl(this._self, this._then);

  final TrackTake _self;
  final $Res Function(TrackTake) _then;

/// Create a copy of TrackTake
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startSamples = freezed,Object? frames = null,Object? sampleRate = null,Object? peaks = null,Object? isStopping = null,}) {
  return _then(_self.copyWith(
startSamples: freezed == startSamples ? _self.startSamples : startSamples // ignore: cast_nullable_to_non_nullable
as int?,frames: null == frames ? _self.frames : frames // ignore: cast_nullable_to_non_nullable
as int,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,peaks: null == peaks ? _self.peaks : peaks // ignore: cast_nullable_to_non_nullable
as IList<double>,isStopping: null == isStopping ? _self.isStopping : isStopping // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackTake].
extension TrackTakePatterns on TrackTake {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackTake value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackTake() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackTake value)  $default,){
final _that = this;
switch (_that) {
case _TrackTake():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackTake value)?  $default,){
final _that = this;
switch (_that) {
case _TrackTake() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? startSamples,  int frames,  int sampleRate,  IList<double> peaks,  bool isStopping)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackTake() when $default != null:
return $default(_that.startSamples,_that.frames,_that.sampleRate,_that.peaks,_that.isStopping);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? startSamples,  int frames,  int sampleRate,  IList<double> peaks,  bool isStopping)  $default,) {final _that = this;
switch (_that) {
case _TrackTake():
return $default(_that.startSamples,_that.frames,_that.sampleRate,_that.peaks,_that.isStopping);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? startSamples,  int frames,  int sampleRate,  IList<double> peaks,  bool isStopping)?  $default,) {final _that = this;
switch (_that) {
case _TrackTake() when $default != null:
return $default(_that.startSamples,_that.frames,_that.sampleRate,_that.peaks,_that.isStopping);case _:
  return null;

}
}

}

/// @nodoc


class _TrackTake implements TrackTake {
  const _TrackTake({this.startSamples, this.frames = 0, this.sampleRate = 0, this.peaks = const IListConst<double>([]), this.isStopping = false});
  

/// Song playhead, in samples, the take starts at; `null` while it waits
/// for playback.
@override final  int? startSamples;
/// Frames recorded so far.
@override@JsonKey() final  int frames;
@override@JsonKey() final  int sampleRate;
/// Lowest and highest sample of every 256 frames, in pairs.
@override@JsonKey() final  IList<double> peaks;
/// Whether the take is being written as a clip.
@override@JsonKey() final  bool isStopping;

/// Create a copy of TrackTake
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackTakeCopyWith<_TrackTake> get copyWith => __$TrackTakeCopyWithImpl<_TrackTake>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackTake&&(identical(other.startSamples, startSamples) || other.startSamples == startSamples)&&(identical(other.frames, frames) || other.frames == frames)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&const DeepCollectionEquality().equals(other.peaks, peaks)&&(identical(other.isStopping, isStopping) || other.isStopping == isStopping));
}


@override
int get hashCode => Object.hash(runtimeType,startSamples,frames,sampleRate,const DeepCollectionEquality().hash(peaks),isStopping);

@override
String toString() {
  return 'TrackTake(startSamples: $startSamples, frames: $frames, sampleRate: $sampleRate, peaks: $peaks, isStopping: $isStopping)';
}


}

/// @nodoc
abstract mixin class _$TrackTakeCopyWith<$Res> implements $TrackTakeCopyWith<$Res> {
  factory _$TrackTakeCopyWith(_TrackTake value, $Res Function(_TrackTake) _then) = __$TrackTakeCopyWithImpl;
@override @useResult
$Res call({
 int? startSamples, int frames, int sampleRate, IList<double> peaks, bool isStopping
});




}
/// @nodoc
class __$TrackTakeCopyWithImpl<$Res>
    implements _$TrackTakeCopyWith<$Res> {
  __$TrackTakeCopyWithImpl(this._self, this._then);

  final _TrackTake _self;
  final $Res Function(_TrackTake) _then;

/// Create a copy of TrackTake
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startSamples = freezed,Object? frames = null,Object? sampleRate = null,Object? peaks = null,Object? isStopping = null,}) {
  return _then(_TrackTake(
startSamples: freezed == startSamples ? _self.startSamples : startSamples // ignore: cast_nullable_to_non_nullable
as int?,frames: null == frames ? _self.frames : frames // ignore: cast_nullable_to_non_nullable
as int,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,peaks: null == peaks ? _self.peaks : peaks // ignore: cast_nullable_to_non_nullable
as IList<double>,isStopping: null == isStopping ? _self.isStopping : isStopping // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$RecordingState {

 IMap<int, TrackTake> get takes;
/// Create a copy of RecordingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecordingStateCopyWith<RecordingState> get copyWith => _$RecordingStateCopyWithImpl<RecordingState>(this as RecordingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecordingState&&(identical(other.takes, takes) || other.takes == takes));
}


@override
int get hashCode => Object.hash(runtimeType,takes);

@override
String toString() {
  return 'RecordingState(takes: $takes)';
}


}

/// @nodoc
abstract mixin class $RecordingStateCopyWith<$Res>  {
  factory $RecordingStateCopyWith(RecordingState value, $Res Function(RecordingState) _then) = _$RecordingStateCopyWithImpl;
@useResult
$Res call({
 IMap<int, TrackTake> takes
});




}
/// @nodoc
class _$RecordingStateCopyWithImpl<$Res>
    implements $RecordingStateCopyWith<$Res> {
  _$RecordingStateCopyWithImpl(this._self, this._then);

  final RecordingState _self;
  final $Res Function(RecordingState) _then;

/// Create a copy of RecordingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? takes = null,}) {
  return _then(_self.copyWith(
takes: null == takes ? _self.takes : takes // ignore: cast_nullable_to_non_nullable
as IMap<int, TrackTake>,
  ));
}

}


/// Adds pattern-matching-related methods to [RecordingState].
extension RecordingStatePatterns on RecordingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecordingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecordingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecordingState value)  $default,){
final _that = this;
switch (_that) {
case _RecordingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecordingState value)?  $default,){
final _that = this;
switch (_that) {
case _RecordingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IMap<int, TrackTake> takes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecordingState() when $default != null:
return $default(_that.takes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IMap<int, TrackTake> takes)  $default,) {final _that = this;
switch (_that) {
case _RecordingState():
return $default(_that.takes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IMap<int, TrackTake> takes)?  $default,) {final _that = this;
switch (_that) {
case _RecordingState() when $default != null:
return $default(_that.takes);case _:
  return null;

}
}

}

/// @nodoc


class _RecordingState implements RecordingState {
  const _RecordingState({this.takes = const IMapConst<int, TrackTake>({})});
  

@override@JsonKey() final  IMap<int, TrackTake> takes;

/// Create a copy of RecordingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecordingStateCopyWith<_RecordingState> get copyWith => __$RecordingStateCopyWithImpl<_RecordingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecordingState&&(identical(other.takes, takes) || other.takes == takes));
}


@override
int get hashCode => Object.hash(runtimeType,takes);

@override
String toString() {
  return 'RecordingState(takes: $takes)';
}


}

/// @nodoc
abstract mixin class _$RecordingStateCopyWith<$Res> implements $RecordingStateCopyWith<$Res> {
  factory _$RecordingStateCopyWith(_RecordingState value, $Res Function(_RecordingState) _then) = __$RecordingStateCopyWithImpl;
@override @useResult
$Res call({
 IMap<int, TrackTake> takes
});




}
/// @nodoc
class __$RecordingStateCopyWithImpl<$Res>
    implements _$RecordingStateCopyWith<$Res> {
  __$RecordingStateCopyWithImpl(this._self, this._then);

  final _RecordingState _self;
  final $Res Function(_RecordingState) _then;

/// Create a copy of RecordingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? takes = null,}) {
  return _then(_RecordingState(
takes: null == takes ? _self.takes : takes // ignore: cast_nullable_to_non_nullable
as IMap<int, TrackTake>,
  ));
}


}

// dart format on
