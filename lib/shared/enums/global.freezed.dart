// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'global.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MixerTarget {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerTarget);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MixerTarget()';
}


}

/// @nodoc
class $MixerTargetCopyWith<$Res>  {
$MixerTargetCopyWith(MixerTarget _, $Res Function(MixerTarget) __);
}


/// Adds pattern-matching-related methods to [MixerTarget].
extension MixerTargetPatterns on MixerTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _MasterMixerTarget value)?  master,TResult Function( _BusMixerTarget value)?  buses,TResult Function( _TrackMixerTarget value)?  tracks,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MasterMixerTarget() when master != null:
return master(_that);case _BusMixerTarget() when buses != null:
return buses(_that);case _TrackMixerTarget() when tracks != null:
return tracks(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _MasterMixerTarget value)  master,required TResult Function( _BusMixerTarget value)  buses,required TResult Function( _TrackMixerTarget value)  tracks,}){
final _that = this;
switch (_that) {
case _MasterMixerTarget():
return master(_that);case _BusMixerTarget():
return buses(_that);case _TrackMixerTarget():
return tracks(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _MasterMixerTarget value)?  master,TResult? Function( _BusMixerTarget value)?  buses,TResult? Function( _TrackMixerTarget value)?  tracks,}){
final _that = this;
switch (_that) {
case _MasterMixerTarget() when master != null:
return master(_that);case _BusMixerTarget() when buses != null:
return buses(_that);case _TrackMixerTarget() when tracks != null:
return tracks(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( UiMixerChannel channel)?  master,TResult Function( Map<int, UiBus> channels)?  buses,TResult Function( Map<int, UiMixerChannel> channels)?  tracks,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MasterMixerTarget() when master != null:
return master(_that.channel);case _BusMixerTarget() when buses != null:
return buses(_that.channels);case _TrackMixerTarget() when tracks != null:
return tracks(_that.channels);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( UiMixerChannel channel)  master,required TResult Function( Map<int, UiBus> channels)  buses,required TResult Function( Map<int, UiMixerChannel> channels)  tracks,}) {final _that = this;
switch (_that) {
case _MasterMixerTarget():
return master(_that.channel);case _BusMixerTarget():
return buses(_that.channels);case _TrackMixerTarget():
return tracks(_that.channels);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( UiMixerChannel channel)?  master,TResult? Function( Map<int, UiBus> channels)?  buses,TResult? Function( Map<int, UiMixerChannel> channels)?  tracks,}) {final _that = this;
switch (_that) {
case _MasterMixerTarget() when master != null:
return master(_that.channel);case _BusMixerTarget() when buses != null:
return buses(_that.channels);case _TrackMixerTarget() when tracks != null:
return tracks(_that.channels);case _:
  return null;

}
}

}

/// @nodoc


class _MasterMixerTarget implements MixerTarget {
  const _MasterMixerTarget(this.channel);
  

 final  UiMixerChannel channel;

/// Create a copy of MixerTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MasterMixerTargetCopyWith<_MasterMixerTarget> get copyWith => __$MasterMixerTargetCopyWithImpl<_MasterMixerTarget>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MasterMixerTarget&&(identical(other.channel, channel) || other.channel == channel));
}


@override
int get hashCode => Object.hash(runtimeType,channel);

@override
String toString() {
  return 'MixerTarget.master(channel: $channel)';
}


}

/// @nodoc
abstract mixin class _$MasterMixerTargetCopyWith<$Res> implements $MixerTargetCopyWith<$Res> {
  factory _$MasterMixerTargetCopyWith(_MasterMixerTarget value, $Res Function(_MasterMixerTarget) _then) = __$MasterMixerTargetCopyWithImpl;
@useResult
$Res call({
 UiMixerChannel channel
});




}
/// @nodoc
class __$MasterMixerTargetCopyWithImpl<$Res>
    implements _$MasterMixerTargetCopyWith<$Res> {
  __$MasterMixerTargetCopyWithImpl(this._self, this._then);

  final _MasterMixerTarget _self;
  final $Res Function(_MasterMixerTarget) _then;

/// Create a copy of MixerTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? channel = null,}) {
  return _then(_MasterMixerTarget(
null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as UiMixerChannel,
  ));
}


}

/// @nodoc


class _BusMixerTarget implements MixerTarget {
  const _BusMixerTarget(final  Map<int, UiBus> channels): _channels = channels;
  

 final  Map<int, UiBus> _channels;
 Map<int, UiBus> get channels {
  if (_channels is EqualUnmodifiableMapView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_channels);
}


/// Create a copy of MixerTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusMixerTargetCopyWith<_BusMixerTarget> get copyWith => __$BusMixerTargetCopyWithImpl<_BusMixerTarget>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusMixerTarget&&const DeepCollectionEquality().equals(other._channels, _channels));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_channels));

@override
String toString() {
  return 'MixerTarget.buses(channels: $channels)';
}


}

/// @nodoc
abstract mixin class _$BusMixerTargetCopyWith<$Res> implements $MixerTargetCopyWith<$Res> {
  factory _$BusMixerTargetCopyWith(_BusMixerTarget value, $Res Function(_BusMixerTarget) _then) = __$BusMixerTargetCopyWithImpl;
@useResult
$Res call({
 Map<int, UiBus> channels
});




}
/// @nodoc
class __$BusMixerTargetCopyWithImpl<$Res>
    implements _$BusMixerTargetCopyWith<$Res> {
  __$BusMixerTargetCopyWithImpl(this._self, this._then);

  final _BusMixerTarget _self;
  final $Res Function(_BusMixerTarget) _then;

/// Create a copy of MixerTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? channels = null,}) {
  return _then(_BusMixerTarget(
null == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as Map<int, UiBus>,
  ));
}


}

/// @nodoc


class _TrackMixerTarget implements MixerTarget {
  const _TrackMixerTarget(final  Map<int, UiMixerChannel> channels): _channels = channels;
  

 final  Map<int, UiMixerChannel> _channels;
 Map<int, UiMixerChannel> get channels {
  if (_channels is EqualUnmodifiableMapView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_channels);
}


/// Create a copy of MixerTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackMixerTargetCopyWith<_TrackMixerTarget> get copyWith => __$TrackMixerTargetCopyWithImpl<_TrackMixerTarget>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackMixerTarget&&const DeepCollectionEquality().equals(other._channels, _channels));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_channels));

@override
String toString() {
  return 'MixerTarget.tracks(channels: $channels)';
}


}

/// @nodoc
abstract mixin class _$TrackMixerTargetCopyWith<$Res> implements $MixerTargetCopyWith<$Res> {
  factory _$TrackMixerTargetCopyWith(_TrackMixerTarget value, $Res Function(_TrackMixerTarget) _then) = __$TrackMixerTargetCopyWithImpl;
@useResult
$Res call({
 Map<int, UiMixerChannel> channels
});




}
/// @nodoc
class __$TrackMixerTargetCopyWithImpl<$Res>
    implements _$TrackMixerTargetCopyWith<$Res> {
  __$TrackMixerTargetCopyWithImpl(this._self, this._then);

  final _TrackMixerTarget _self;
  final $Res Function(_TrackMixerTarget) _then;

/// Create a copy of MixerTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? channels = null,}) {
  return _then(_TrackMixerTarget(
null == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as Map<int, UiMixerChannel>,
  ));
}


}

// dart format on
