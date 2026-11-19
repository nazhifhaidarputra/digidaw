// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'range_select_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TimelineRow {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimelineRow);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TimelineRow()';
}


}

/// @nodoc
class $TimelineRowCopyWith<$Res>  {
$TimelineRowCopyWith(TimelineRow _, $Res Function(TimelineRow) __);
}


/// Adds pattern-matching-related methods to [TimelineRow].
extension TimelineRowPatterns on TimelineRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TimelineTrackRow value)?  track,TResult Function( TimelineLaneRow value)?  lane,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TimelineTrackRow() when track != null:
return track(_that);case TimelineLaneRow() when lane != null:
return lane(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TimelineTrackRow value)  track,required TResult Function( TimelineLaneRow value)  lane,}){
final _that = this;
switch (_that) {
case TimelineTrackRow():
return track(_that);case TimelineLaneRow():
return lane(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TimelineTrackRow value)?  track,TResult? Function( TimelineLaneRow value)?  lane,}){
final _that = this;
switch (_that) {
case TimelineTrackRow() when track != null:
return track(_that);case TimelineLaneRow() when lane != null:
return lane(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int trackId)?  track,TResult Function( int laneId)?  lane,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TimelineTrackRow() when track != null:
return track(_that.trackId);case TimelineLaneRow() when lane != null:
return lane(_that.laneId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int trackId)  track,required TResult Function( int laneId)  lane,}) {final _that = this;
switch (_that) {
case TimelineTrackRow():
return track(_that.trackId);case TimelineLaneRow():
return lane(_that.laneId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int trackId)?  track,TResult? Function( int laneId)?  lane,}) {final _that = this;
switch (_that) {
case TimelineTrackRow() when track != null:
return track(_that.trackId);case TimelineLaneRow() when lane != null:
return lane(_that.laneId);case _:
  return null;

}
}

}

/// @nodoc


class TimelineTrackRow implements TimelineRow {
  const TimelineTrackRow(this.trackId);
  

 final  int trackId;

/// Create a copy of TimelineRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimelineTrackRowCopyWith<TimelineTrackRow> get copyWith => _$TimelineTrackRowCopyWithImpl<TimelineTrackRow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimelineTrackRow&&(identical(other.trackId, trackId) || other.trackId == trackId));
}


@override
int get hashCode => Object.hash(runtimeType,trackId);

@override
String toString() {
  return 'TimelineRow.track(trackId: $trackId)';
}


}

/// @nodoc
abstract mixin class $TimelineTrackRowCopyWith<$Res> implements $TimelineRowCopyWith<$Res> {
  factory $TimelineTrackRowCopyWith(TimelineTrackRow value, $Res Function(TimelineTrackRow) _then) = _$TimelineTrackRowCopyWithImpl;
@useResult
$Res call({
 int trackId
});




}
/// @nodoc
class _$TimelineTrackRowCopyWithImpl<$Res>
    implements $TimelineTrackRowCopyWith<$Res> {
  _$TimelineTrackRowCopyWithImpl(this._self, this._then);

  final TimelineTrackRow _self;
  final $Res Function(TimelineTrackRow) _then;

/// Create a copy of TimelineRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,}) {
  return _then(TimelineTrackRow(
null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class TimelineLaneRow implements TimelineRow {
  const TimelineLaneRow(this.laneId);
  

 final  int laneId;

/// Create a copy of TimelineRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimelineLaneRowCopyWith<TimelineLaneRow> get copyWith => _$TimelineLaneRowCopyWithImpl<TimelineLaneRow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimelineLaneRow&&(identical(other.laneId, laneId) || other.laneId == laneId));
}


@override
int get hashCode => Object.hash(runtimeType,laneId);

@override
String toString() {
  return 'TimelineRow.lane(laneId: $laneId)';
}


}

/// @nodoc
abstract mixin class $TimelineLaneRowCopyWith<$Res> implements $TimelineRowCopyWith<$Res> {
  factory $TimelineLaneRowCopyWith(TimelineLaneRow value, $Res Function(TimelineLaneRow) _then) = _$TimelineLaneRowCopyWithImpl;
@useResult
$Res call({
 int laneId
});




}
/// @nodoc
class _$TimelineLaneRowCopyWithImpl<$Res>
    implements $TimelineLaneRowCopyWith<$Res> {
  _$TimelineLaneRowCopyWithImpl(this._self, this._then);

  final TimelineLaneRow _self;
  final $Res Function(TimelineLaneRow) _then;

/// Create a copy of TimelineRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? laneId = null,}) {
  return _then(TimelineLaneRow(
null == laneId ? _self.laneId : laneId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$TickSpan {

 int get start; int get end;
/// Create a copy of TickSpan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TickSpanCopyWith<TickSpan> get copyWith => _$TickSpanCopyWithImpl<TickSpan>(this as TickSpan, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TickSpan&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}


@override
int get hashCode => Object.hash(runtimeType,start,end);

@override
String toString() {
  return 'TickSpan(start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class $TickSpanCopyWith<$Res>  {
  factory $TickSpanCopyWith(TickSpan value, $Res Function(TickSpan) _then) = _$TickSpanCopyWithImpl;
@useResult
$Res call({
 int start, int end
});




}
/// @nodoc
class _$TickSpanCopyWithImpl<$Res>
    implements $TickSpanCopyWith<$Res> {
  _$TickSpanCopyWithImpl(this._self, this._then);

  final TickSpan _self;
  final $Res Function(TickSpan) _then;

/// Create a copy of TickSpan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = null,Object? end = null,}) {
  return _then(_self.copyWith(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _TickSpan extends TickSpan {
  const _TickSpan({required this.start, required this.end}): super._();
  

@override final  int start;
@override final  int end;

/// Create a copy of TickSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TickSpanCopyWith<_TickSpan> get copyWith => __$TickSpanCopyWithImpl<_TickSpan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TickSpan&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}


@override
int get hashCode => Object.hash(runtimeType,start,end);

@override
String toString() {
  return 'TickSpan._raw(start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class _$TickSpanCopyWith<$Res> implements $TickSpanCopyWith<$Res> {
  factory _$TickSpanCopyWith(_TickSpan value, $Res Function(_TickSpan) _then) = __$TickSpanCopyWithImpl;
@override @useResult
$Res call({
 int start, int end
});




}
/// @nodoc
class __$TickSpanCopyWithImpl<$Res>
    implements _$TickSpanCopyWith<$Res> {
  __$TickSpanCopyWithImpl(this._self, this._then);

  final _TickSpan _self;
  final $Res Function(_TickSpan) _then;

/// Create a copy of TickSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = null,Object? end = null,}) {
  return _then(_TickSpan(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$RangeSelectState {

 bool get isSelecting;/// Row where the drag started; null for a range drawn on the ruler.
 TimelineRow? get anchorRow;/// Row under the pointer, or the last row it passed over.
 TimelineRow? get focusRow;/// Drag start in ticks.
 double get startTick;/// Current drag end in ticks.
 double get endTick;/// Time range kept highlighted on the ruler after a range drawn there
/// ends. It outlives the clip selection it made; a double click on it, or
/// Escape with nothing else selected, clears it.
 TickSpan? get timeRange;
/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RangeSelectStateCopyWith<RangeSelectState> get copyWith => _$RangeSelectStateCopyWithImpl<RangeSelectState>(this as RangeSelectState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RangeSelectState&&(identical(other.isSelecting, isSelecting) || other.isSelecting == isSelecting)&&(identical(other.anchorRow, anchorRow) || other.anchorRow == anchorRow)&&(identical(other.focusRow, focusRow) || other.focusRow == focusRow)&&(identical(other.startTick, startTick) || other.startTick == startTick)&&(identical(other.endTick, endTick) || other.endTick == endTick)&&(identical(other.timeRange, timeRange) || other.timeRange == timeRange));
}


@override
int get hashCode => Object.hash(runtimeType,isSelecting,anchorRow,focusRow,startTick,endTick,timeRange);

@override
String toString() {
  return 'RangeSelectState(isSelecting: $isSelecting, anchorRow: $anchorRow, focusRow: $focusRow, startTick: $startTick, endTick: $endTick, timeRange: $timeRange)';
}


}

/// @nodoc
abstract mixin class $RangeSelectStateCopyWith<$Res>  {
  factory $RangeSelectStateCopyWith(RangeSelectState value, $Res Function(RangeSelectState) _then) = _$RangeSelectStateCopyWithImpl;
@useResult
$Res call({
 bool isSelecting, TimelineRow? anchorRow, TimelineRow? focusRow, double startTick, double endTick, TickSpan? timeRange
});


$TimelineRowCopyWith<$Res>? get anchorRow;$TimelineRowCopyWith<$Res>? get focusRow;$TickSpanCopyWith<$Res>? get timeRange;

}
/// @nodoc
class _$RangeSelectStateCopyWithImpl<$Res>
    implements $RangeSelectStateCopyWith<$Res> {
  _$RangeSelectStateCopyWithImpl(this._self, this._then);

  final RangeSelectState _self;
  final $Res Function(RangeSelectState) _then;

/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isSelecting = null,Object? anchorRow = freezed,Object? focusRow = freezed,Object? startTick = null,Object? endTick = null,Object? timeRange = freezed,}) {
  return _then(_self.copyWith(
isSelecting: null == isSelecting ? _self.isSelecting : isSelecting // ignore: cast_nullable_to_non_nullable
as bool,anchorRow: freezed == anchorRow ? _self.anchorRow : anchorRow // ignore: cast_nullable_to_non_nullable
as TimelineRow?,focusRow: freezed == focusRow ? _self.focusRow : focusRow // ignore: cast_nullable_to_non_nullable
as TimelineRow?,startTick: null == startTick ? _self.startTick : startTick // ignore: cast_nullable_to_non_nullable
as double,endTick: null == endTick ? _self.endTick : endTick // ignore: cast_nullable_to_non_nullable
as double,timeRange: freezed == timeRange ? _self.timeRange : timeRange // ignore: cast_nullable_to_non_nullable
as TickSpan?,
  ));
}
/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TimelineRowCopyWith<$Res>? get anchorRow {
    if (_self.anchorRow == null) {
    return null;
  }

  return $TimelineRowCopyWith<$Res>(_self.anchorRow!, (value) {
    return _then(_self.copyWith(anchorRow: value));
  });
}/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TimelineRowCopyWith<$Res>? get focusRow {
    if (_self.focusRow == null) {
    return null;
  }

  return $TimelineRowCopyWith<$Res>(_self.focusRow!, (value) {
    return _then(_self.copyWith(focusRow: value));
  });
}/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TickSpanCopyWith<$Res>? get timeRange {
    if (_self.timeRange == null) {
    return null;
  }

  return $TickSpanCopyWith<$Res>(_self.timeRange!, (value) {
    return _then(_self.copyWith(timeRange: value));
  });
}
}


/// Adds pattern-matching-related methods to [RangeSelectState].
extension RangeSelectStatePatterns on RangeSelectState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RangeSelectState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RangeSelectState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RangeSelectState value)  $default,){
final _that = this;
switch (_that) {
case _RangeSelectState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RangeSelectState value)?  $default,){
final _that = this;
switch (_that) {
case _RangeSelectState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isSelecting,  TimelineRow? anchorRow,  TimelineRow? focusRow,  double startTick,  double endTick,  TickSpan? timeRange)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RangeSelectState() when $default != null:
return $default(_that.isSelecting,_that.anchorRow,_that.focusRow,_that.startTick,_that.endTick,_that.timeRange);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isSelecting,  TimelineRow? anchorRow,  TimelineRow? focusRow,  double startTick,  double endTick,  TickSpan? timeRange)  $default,) {final _that = this;
switch (_that) {
case _RangeSelectState():
return $default(_that.isSelecting,_that.anchorRow,_that.focusRow,_that.startTick,_that.endTick,_that.timeRange);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isSelecting,  TimelineRow? anchorRow,  TimelineRow? focusRow,  double startTick,  double endTick,  TickSpan? timeRange)?  $default,) {final _that = this;
switch (_that) {
case _RangeSelectState() when $default != null:
return $default(_that.isSelecting,_that.anchorRow,_that.focusRow,_that.startTick,_that.endTick,_that.timeRange);case _:
  return null;

}
}

}

/// @nodoc


class _RangeSelectState extends RangeSelectState {
  const _RangeSelectState({this.isSelecting = false, this.anchorRow, this.focusRow, this.startTick = 0, this.endTick = 0, this.timeRange}): super._();
  

@override@JsonKey() final  bool isSelecting;
/// Row where the drag started; null for a range drawn on the ruler.
@override final  TimelineRow? anchorRow;
/// Row under the pointer, or the last row it passed over.
@override final  TimelineRow? focusRow;
/// Drag start in ticks.
@override@JsonKey() final  double startTick;
/// Current drag end in ticks.
@override@JsonKey() final  double endTick;
/// Time range kept highlighted on the ruler after a range drawn there
/// ends. It outlives the clip selection it made; a double click on it, or
/// Escape with nothing else selected, clears it.
@override final  TickSpan? timeRange;

/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RangeSelectStateCopyWith<_RangeSelectState> get copyWith => __$RangeSelectStateCopyWithImpl<_RangeSelectState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RangeSelectState&&(identical(other.isSelecting, isSelecting) || other.isSelecting == isSelecting)&&(identical(other.anchorRow, anchorRow) || other.anchorRow == anchorRow)&&(identical(other.focusRow, focusRow) || other.focusRow == focusRow)&&(identical(other.startTick, startTick) || other.startTick == startTick)&&(identical(other.endTick, endTick) || other.endTick == endTick)&&(identical(other.timeRange, timeRange) || other.timeRange == timeRange));
}


@override
int get hashCode => Object.hash(runtimeType,isSelecting,anchorRow,focusRow,startTick,endTick,timeRange);

@override
String toString() {
  return 'RangeSelectState(isSelecting: $isSelecting, anchorRow: $anchorRow, focusRow: $focusRow, startTick: $startTick, endTick: $endTick, timeRange: $timeRange)';
}


}

/// @nodoc
abstract mixin class _$RangeSelectStateCopyWith<$Res> implements $RangeSelectStateCopyWith<$Res> {
  factory _$RangeSelectStateCopyWith(_RangeSelectState value, $Res Function(_RangeSelectState) _then) = __$RangeSelectStateCopyWithImpl;
@override @useResult
$Res call({
 bool isSelecting, TimelineRow? anchorRow, TimelineRow? focusRow, double startTick, double endTick, TickSpan? timeRange
});


@override $TimelineRowCopyWith<$Res>? get anchorRow;@override $TimelineRowCopyWith<$Res>? get focusRow;@override $TickSpanCopyWith<$Res>? get timeRange;

}
/// @nodoc
class __$RangeSelectStateCopyWithImpl<$Res>
    implements _$RangeSelectStateCopyWith<$Res> {
  __$RangeSelectStateCopyWithImpl(this._self, this._then);

  final _RangeSelectState _self;
  final $Res Function(_RangeSelectState) _then;

/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isSelecting = null,Object? anchorRow = freezed,Object? focusRow = freezed,Object? startTick = null,Object? endTick = null,Object? timeRange = freezed,}) {
  return _then(_RangeSelectState(
isSelecting: null == isSelecting ? _self.isSelecting : isSelecting // ignore: cast_nullable_to_non_nullable
as bool,anchorRow: freezed == anchorRow ? _self.anchorRow : anchorRow // ignore: cast_nullable_to_non_nullable
as TimelineRow?,focusRow: freezed == focusRow ? _self.focusRow : focusRow // ignore: cast_nullable_to_non_nullable
as TimelineRow?,startTick: null == startTick ? _self.startTick : startTick // ignore: cast_nullable_to_non_nullable
as double,endTick: null == endTick ? _self.endTick : endTick // ignore: cast_nullable_to_non_nullable
as double,timeRange: freezed == timeRange ? _self.timeRange : timeRange // ignore: cast_nullable_to_non_nullable
as TickSpan?,
  ));
}

/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TimelineRowCopyWith<$Res>? get anchorRow {
    if (_self.anchorRow == null) {
    return null;
  }

  return $TimelineRowCopyWith<$Res>(_self.anchorRow!, (value) {
    return _then(_self.copyWith(anchorRow: value));
  });
}/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TimelineRowCopyWith<$Res>? get focusRow {
    if (_self.focusRow == null) {
    return null;
  }

  return $TimelineRowCopyWith<$Res>(_self.focusRow!, (value) {
    return _then(_self.copyWith(focusRow: value));
  });
}/// Create a copy of RangeSelectState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TickSpanCopyWith<$Res>? get timeRange {
    if (_self.timeRange == null) {
    return null;
  }

  return $TickSpanCopyWith<$Res>(_self.timeRange!, (value) {
    return _then(_self.copyWith(timeRange: value));
  });
}
}

// dart format on
