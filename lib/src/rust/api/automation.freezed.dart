// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'automation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutomationTargetDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutomationTargetDto()';
}


}

/// @nodoc
class $AutomationTargetDtoCopyWith<$Res>  {
$AutomationTargetDtoCopyWith(AutomationTargetDto _, $Res Function(AutomationTargetDto) __);
}


/// Adds pattern-matching-related methods to [AutomationTargetDto].
extension AutomationTargetDtoPatterns on AutomationTargetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AutomationTargetDto_TrackGeneratorPluginParam value)?  trackGeneratorPluginParam,TResult Function( AutomationTargetDto_Track value)?  track,TResult Function( AutomationTargetDto_Bus value)?  bus,TResult Function( AutomationTargetDto_Master value)?  master,TResult Function( AutomationTargetDto_TempoBpm value)?  tempoBpm,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AutomationTargetDto_TrackGeneratorPluginParam() when trackGeneratorPluginParam != null:
return trackGeneratorPluginParam(_that);case AutomationTargetDto_Track() when track != null:
return track(_that);case AutomationTargetDto_Bus() when bus != null:
return bus(_that);case AutomationTargetDto_Master() when master != null:
return master(_that);case AutomationTargetDto_TempoBpm() when tempoBpm != null:
return tempoBpm(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AutomationTargetDto_TrackGeneratorPluginParam value)  trackGeneratorPluginParam,required TResult Function( AutomationTargetDto_Track value)  track,required TResult Function( AutomationTargetDto_Bus value)  bus,required TResult Function( AutomationTargetDto_Master value)  master,required TResult Function( AutomationTargetDto_TempoBpm value)  tempoBpm,}){
final _that = this;
switch (_that) {
case AutomationTargetDto_TrackGeneratorPluginParam():
return trackGeneratorPluginParam(_that);case AutomationTargetDto_Track():
return track(_that);case AutomationTargetDto_Bus():
return bus(_that);case AutomationTargetDto_Master():
return master(_that);case AutomationTargetDto_TempoBpm():
return tempoBpm(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AutomationTargetDto_TrackGeneratorPluginParam value)?  trackGeneratorPluginParam,TResult? Function( AutomationTargetDto_Track value)?  track,TResult? Function( AutomationTargetDto_Bus value)?  bus,TResult? Function( AutomationTargetDto_Master value)?  master,TResult? Function( AutomationTargetDto_TempoBpm value)?  tempoBpm,}){
final _that = this;
switch (_that) {
case AutomationTargetDto_TrackGeneratorPluginParam() when trackGeneratorPluginParam != null:
return trackGeneratorPluginParam(_that);case AutomationTargetDto_Track() when track != null:
return track(_that);case AutomationTargetDto_Bus() when bus != null:
return bus(_that);case AutomationTargetDto_Master() when master != null:
return master(_that);case AutomationTargetDto_TempoBpm() when tempoBpm != null:
return tempoBpm(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int trackId,  int paramId)?  trackGeneratorPluginParam,TResult Function( int trackId,  MixerChannelTargetDto mixTarget)?  track,TResult Function( int busId,  MixerChannelTargetDto mixTarget)?  bus,TResult Function( MixerChannelTargetDto field0)?  master,TResult Function()?  tempoBpm,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AutomationTargetDto_TrackGeneratorPluginParam() when trackGeneratorPluginParam != null:
return trackGeneratorPluginParam(_that.trackId,_that.paramId);case AutomationTargetDto_Track() when track != null:
return track(_that.trackId,_that.mixTarget);case AutomationTargetDto_Bus() when bus != null:
return bus(_that.busId,_that.mixTarget);case AutomationTargetDto_Master() when master != null:
return master(_that.field0);case AutomationTargetDto_TempoBpm() when tempoBpm != null:
return tempoBpm();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int trackId,  int paramId)  trackGeneratorPluginParam,required TResult Function( int trackId,  MixerChannelTargetDto mixTarget)  track,required TResult Function( int busId,  MixerChannelTargetDto mixTarget)  bus,required TResult Function( MixerChannelTargetDto field0)  master,required TResult Function()  tempoBpm,}) {final _that = this;
switch (_that) {
case AutomationTargetDto_TrackGeneratorPluginParam():
return trackGeneratorPluginParam(_that.trackId,_that.paramId);case AutomationTargetDto_Track():
return track(_that.trackId,_that.mixTarget);case AutomationTargetDto_Bus():
return bus(_that.busId,_that.mixTarget);case AutomationTargetDto_Master():
return master(_that.field0);case AutomationTargetDto_TempoBpm():
return tempoBpm();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int trackId,  int paramId)?  trackGeneratorPluginParam,TResult? Function( int trackId,  MixerChannelTargetDto mixTarget)?  track,TResult? Function( int busId,  MixerChannelTargetDto mixTarget)?  bus,TResult? Function( MixerChannelTargetDto field0)?  master,TResult? Function()?  tempoBpm,}) {final _that = this;
switch (_that) {
case AutomationTargetDto_TrackGeneratorPluginParam() when trackGeneratorPluginParam != null:
return trackGeneratorPluginParam(_that.trackId,_that.paramId);case AutomationTargetDto_Track() when track != null:
return track(_that.trackId,_that.mixTarget);case AutomationTargetDto_Bus() when bus != null:
return bus(_that.busId,_that.mixTarget);case AutomationTargetDto_Master() when master != null:
return master(_that.field0);case AutomationTargetDto_TempoBpm() when tempoBpm != null:
return tempoBpm();case _:
  return null;

}
}

}

/// @nodoc


class AutomationTargetDto_TrackGeneratorPluginParam extends AutomationTargetDto {
  const AutomationTargetDto_TrackGeneratorPluginParam({required this.trackId, required this.paramId}): super._();
  

 final  int trackId;
 final  int paramId;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationTargetDto_TrackGeneratorPluginParamCopyWith<AutomationTargetDto_TrackGeneratorPluginParam> get copyWith => _$AutomationTargetDto_TrackGeneratorPluginParamCopyWithImpl<AutomationTargetDto_TrackGeneratorPluginParam>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_TrackGeneratorPluginParam&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.paramId, paramId) || other.paramId == paramId));
}


@override
int get hashCode => Object.hash(runtimeType,trackId,paramId);

@override
String toString() {
  return 'AutomationTargetDto.trackGeneratorPluginParam(trackId: $trackId, paramId: $paramId)';
}


}

/// @nodoc
abstract mixin class $AutomationTargetDto_TrackGeneratorPluginParamCopyWith<$Res> implements $AutomationTargetDtoCopyWith<$Res> {
  factory $AutomationTargetDto_TrackGeneratorPluginParamCopyWith(AutomationTargetDto_TrackGeneratorPluginParam value, $Res Function(AutomationTargetDto_TrackGeneratorPluginParam) _then) = _$AutomationTargetDto_TrackGeneratorPluginParamCopyWithImpl;
@useResult
$Res call({
 int trackId, int paramId
});




}
/// @nodoc
class _$AutomationTargetDto_TrackGeneratorPluginParamCopyWithImpl<$Res>
    implements $AutomationTargetDto_TrackGeneratorPluginParamCopyWith<$Res> {
  _$AutomationTargetDto_TrackGeneratorPluginParamCopyWithImpl(this._self, this._then);

  final AutomationTargetDto_TrackGeneratorPluginParam _self;
  final $Res Function(AutomationTargetDto_TrackGeneratorPluginParam) _then;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? paramId = null,}) {
  return _then(AutomationTargetDto_TrackGeneratorPluginParam(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,paramId: null == paramId ? _self.paramId : paramId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class AutomationTargetDto_Track extends AutomationTargetDto {
  const AutomationTargetDto_Track({required this.trackId, required this.mixTarget}): super._();
  

 final  int trackId;
 final  MixerChannelTargetDto mixTarget;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationTargetDto_TrackCopyWith<AutomationTargetDto_Track> get copyWith => _$AutomationTargetDto_TrackCopyWithImpl<AutomationTargetDto_Track>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_Track&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.mixTarget, mixTarget) || other.mixTarget == mixTarget));
}


@override
int get hashCode => Object.hash(runtimeType,trackId,mixTarget);

@override
String toString() {
  return 'AutomationTargetDto.track(trackId: $trackId, mixTarget: $mixTarget)';
}


}

/// @nodoc
abstract mixin class $AutomationTargetDto_TrackCopyWith<$Res> implements $AutomationTargetDtoCopyWith<$Res> {
  factory $AutomationTargetDto_TrackCopyWith(AutomationTargetDto_Track value, $Res Function(AutomationTargetDto_Track) _then) = _$AutomationTargetDto_TrackCopyWithImpl;
@useResult
$Res call({
 int trackId, MixerChannelTargetDto mixTarget
});


$MixerChannelTargetDtoCopyWith<$Res> get mixTarget;

}
/// @nodoc
class _$AutomationTargetDto_TrackCopyWithImpl<$Res>
    implements $AutomationTargetDto_TrackCopyWith<$Res> {
  _$AutomationTargetDto_TrackCopyWithImpl(this._self, this._then);

  final AutomationTargetDto_Track _self;
  final $Res Function(AutomationTargetDto_Track) _then;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? mixTarget = null,}) {
  return _then(AutomationTargetDto_Track(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,mixTarget: null == mixTarget ? _self.mixTarget : mixTarget // ignore: cast_nullable_to_non_nullable
as MixerChannelTargetDto,
  ));
}

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MixerChannelTargetDtoCopyWith<$Res> get mixTarget {
  
  return $MixerChannelTargetDtoCopyWith<$Res>(_self.mixTarget, (value) {
    return _then(_self.copyWith(mixTarget: value));
  });
}
}

/// @nodoc


class AutomationTargetDto_Bus extends AutomationTargetDto {
  const AutomationTargetDto_Bus({required this.busId, required this.mixTarget}): super._();
  

 final  int busId;
 final  MixerChannelTargetDto mixTarget;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationTargetDto_BusCopyWith<AutomationTargetDto_Bus> get copyWith => _$AutomationTargetDto_BusCopyWithImpl<AutomationTargetDto_Bus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_Bus&&(identical(other.busId, busId) || other.busId == busId)&&(identical(other.mixTarget, mixTarget) || other.mixTarget == mixTarget));
}


@override
int get hashCode => Object.hash(runtimeType,busId,mixTarget);

@override
String toString() {
  return 'AutomationTargetDto.bus(busId: $busId, mixTarget: $mixTarget)';
}


}

/// @nodoc
abstract mixin class $AutomationTargetDto_BusCopyWith<$Res> implements $AutomationTargetDtoCopyWith<$Res> {
  factory $AutomationTargetDto_BusCopyWith(AutomationTargetDto_Bus value, $Res Function(AutomationTargetDto_Bus) _then) = _$AutomationTargetDto_BusCopyWithImpl;
@useResult
$Res call({
 int busId, MixerChannelTargetDto mixTarget
});


$MixerChannelTargetDtoCopyWith<$Res> get mixTarget;

}
/// @nodoc
class _$AutomationTargetDto_BusCopyWithImpl<$Res>
    implements $AutomationTargetDto_BusCopyWith<$Res> {
  _$AutomationTargetDto_BusCopyWithImpl(this._self, this._then);

  final AutomationTargetDto_Bus _self;
  final $Res Function(AutomationTargetDto_Bus) _then;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? busId = null,Object? mixTarget = null,}) {
  return _then(AutomationTargetDto_Bus(
busId: null == busId ? _self.busId : busId // ignore: cast_nullable_to_non_nullable
as int,mixTarget: null == mixTarget ? _self.mixTarget : mixTarget // ignore: cast_nullable_to_non_nullable
as MixerChannelTargetDto,
  ));
}

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MixerChannelTargetDtoCopyWith<$Res> get mixTarget {
  
  return $MixerChannelTargetDtoCopyWith<$Res>(_self.mixTarget, (value) {
    return _then(_self.copyWith(mixTarget: value));
  });
}
}

/// @nodoc


class AutomationTargetDto_Master extends AutomationTargetDto {
  const AutomationTargetDto_Master(this.field0): super._();
  

 final  MixerChannelTargetDto field0;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationTargetDto_MasterCopyWith<AutomationTargetDto_Master> get copyWith => _$AutomationTargetDto_MasterCopyWithImpl<AutomationTargetDto_Master>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_Master&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'AutomationTargetDto.master(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $AutomationTargetDto_MasterCopyWith<$Res> implements $AutomationTargetDtoCopyWith<$Res> {
  factory $AutomationTargetDto_MasterCopyWith(AutomationTargetDto_Master value, $Res Function(AutomationTargetDto_Master) _then) = _$AutomationTargetDto_MasterCopyWithImpl;
@useResult
$Res call({
 MixerChannelTargetDto field0
});


$MixerChannelTargetDtoCopyWith<$Res> get field0;

}
/// @nodoc
class _$AutomationTargetDto_MasterCopyWithImpl<$Res>
    implements $AutomationTargetDto_MasterCopyWith<$Res> {
  _$AutomationTargetDto_MasterCopyWithImpl(this._self, this._then);

  final AutomationTargetDto_Master _self;
  final $Res Function(AutomationTargetDto_Master) _then;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(AutomationTargetDto_Master(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as MixerChannelTargetDto,
  ));
}

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MixerChannelTargetDtoCopyWith<$Res> get field0 {
  
  return $MixerChannelTargetDtoCopyWith<$Res>(_self.field0, (value) {
    return _then(_self.copyWith(field0: value));
  });
}
}

/// @nodoc


class AutomationTargetDto_TempoBpm extends AutomationTargetDto {
  const AutomationTargetDto_TempoBpm(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_TempoBpm);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutomationTargetDto.tempoBpm()';
}


}




/// @nodoc
mixin _$EffectAutomationTargetDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EffectAutomationTargetDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EffectAutomationTargetDto()';
}


}

/// @nodoc
class $EffectAutomationTargetDtoCopyWith<$Res>  {
$EffectAutomationTargetDtoCopyWith(EffectAutomationTargetDto _, $Res Function(EffectAutomationTargetDto) __);
}


/// Adds pattern-matching-related methods to [EffectAutomationTargetDto].
extension EffectAutomationTargetDtoPatterns on EffectAutomationTargetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( EffectAutomationTargetDto_Mix value)?  mix,TResult Function( EffectAutomationTargetDto_PluginParam value)?  pluginParam,required TResult orElse(),}){
final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix() when mix != null:
return mix(_that);case EffectAutomationTargetDto_PluginParam() when pluginParam != null:
return pluginParam(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( EffectAutomationTargetDto_Mix value)  mix,required TResult Function( EffectAutomationTargetDto_PluginParam value)  pluginParam,}){
final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix():
return mix(_that);case EffectAutomationTargetDto_PluginParam():
return pluginParam(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( EffectAutomationTargetDto_Mix value)?  mix,TResult? Function( EffectAutomationTargetDto_PluginParam value)?  pluginParam,}){
final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix() when mix != null:
return mix(_that);case EffectAutomationTargetDto_PluginParam() when pluginParam != null:
return pluginParam(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  mix,TResult Function( int paramId)?  pluginParam,required TResult orElse(),}) {final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix() when mix != null:
return mix();case EffectAutomationTargetDto_PluginParam() when pluginParam != null:
return pluginParam(_that.paramId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  mix,required TResult Function( int paramId)  pluginParam,}) {final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix():
return mix();case EffectAutomationTargetDto_PluginParam():
return pluginParam(_that.paramId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  mix,TResult? Function( int paramId)?  pluginParam,}) {final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix() when mix != null:
return mix();case EffectAutomationTargetDto_PluginParam() when pluginParam != null:
return pluginParam(_that.paramId);case _:
  return null;

}
}

}

/// @nodoc


class EffectAutomationTargetDto_Mix extends EffectAutomationTargetDto {
  const EffectAutomationTargetDto_Mix(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EffectAutomationTargetDto_Mix);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EffectAutomationTargetDto.mix()';
}


}




/// @nodoc


class EffectAutomationTargetDto_PluginParam extends EffectAutomationTargetDto {
  const EffectAutomationTargetDto_PluginParam({required this.paramId}): super._();
  

 final  int paramId;

/// Create a copy of EffectAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EffectAutomationTargetDto_PluginParamCopyWith<EffectAutomationTargetDto_PluginParam> get copyWith => _$EffectAutomationTargetDto_PluginParamCopyWithImpl<EffectAutomationTargetDto_PluginParam>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EffectAutomationTargetDto_PluginParam&&(identical(other.paramId, paramId) || other.paramId == paramId));
}


@override
int get hashCode => Object.hash(runtimeType,paramId);

@override
String toString() {
  return 'EffectAutomationTargetDto.pluginParam(paramId: $paramId)';
}


}

/// @nodoc
abstract mixin class $EffectAutomationTargetDto_PluginParamCopyWith<$Res> implements $EffectAutomationTargetDtoCopyWith<$Res> {
  factory $EffectAutomationTargetDto_PluginParamCopyWith(EffectAutomationTargetDto_PluginParam value, $Res Function(EffectAutomationTargetDto_PluginParam) _then) = _$EffectAutomationTargetDto_PluginParamCopyWithImpl;
@useResult
$Res call({
 int paramId
});




}
/// @nodoc
class _$EffectAutomationTargetDto_PluginParamCopyWithImpl<$Res>
    implements $EffectAutomationTargetDto_PluginParamCopyWith<$Res> {
  _$EffectAutomationTargetDto_PluginParamCopyWithImpl(this._self, this._then);

  final EffectAutomationTargetDto_PluginParam _self;
  final $Res Function(EffectAutomationTargetDto_PluginParam) _then;

/// Create a copy of EffectAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? paramId = null,}) {
  return _then(EffectAutomationTargetDto_PluginParam(
paramId: null == paramId ? _self.paramId : paramId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$MixerChannelTargetDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelTargetDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MixerChannelTargetDto()';
}


}

/// @nodoc
class $MixerChannelTargetDtoCopyWith<$Res>  {
$MixerChannelTargetDtoCopyWith(MixerChannelTargetDto _, $Res Function(MixerChannelTargetDto) __);
}


/// Adds pattern-matching-related methods to [MixerChannelTargetDto].
extension MixerChannelTargetDtoPatterns on MixerChannelTargetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( MixerChannelTargetDto_Volume value)?  volume,TResult Function( MixerChannelTargetDto_Pan value)?  pan,TResult Function( MixerChannelTargetDto_Plugin value)?  plugin,required TResult orElse(),}){
final _that = this;
switch (_that) {
case MixerChannelTargetDto_Volume() when volume != null:
return volume(_that);case MixerChannelTargetDto_Pan() when pan != null:
return pan(_that);case MixerChannelTargetDto_Plugin() when plugin != null:
return plugin(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( MixerChannelTargetDto_Volume value)  volume,required TResult Function( MixerChannelTargetDto_Pan value)  pan,required TResult Function( MixerChannelTargetDto_Plugin value)  plugin,}){
final _that = this;
switch (_that) {
case MixerChannelTargetDto_Volume():
return volume(_that);case MixerChannelTargetDto_Pan():
return pan(_that);case MixerChannelTargetDto_Plugin():
return plugin(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( MixerChannelTargetDto_Volume value)?  volume,TResult? Function( MixerChannelTargetDto_Pan value)?  pan,TResult? Function( MixerChannelTargetDto_Plugin value)?  plugin,}){
final _that = this;
switch (_that) {
case MixerChannelTargetDto_Volume() when volume != null:
return volume(_that);case MixerChannelTargetDto_Pan() when pan != null:
return pan(_that);case MixerChannelTargetDto_Plugin() when plugin != null:
return plugin(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  volume,TResult Function()?  pan,TResult Function( int effectId,  EffectAutomationTargetDto target)?  plugin,required TResult orElse(),}) {final _that = this;
switch (_that) {
case MixerChannelTargetDto_Volume() when volume != null:
return volume();case MixerChannelTargetDto_Pan() when pan != null:
return pan();case MixerChannelTargetDto_Plugin() when plugin != null:
return plugin(_that.effectId,_that.target);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  volume,required TResult Function()  pan,required TResult Function( int effectId,  EffectAutomationTargetDto target)  plugin,}) {final _that = this;
switch (_that) {
case MixerChannelTargetDto_Volume():
return volume();case MixerChannelTargetDto_Pan():
return pan();case MixerChannelTargetDto_Plugin():
return plugin(_that.effectId,_that.target);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  volume,TResult? Function()?  pan,TResult? Function( int effectId,  EffectAutomationTargetDto target)?  plugin,}) {final _that = this;
switch (_that) {
case MixerChannelTargetDto_Volume() when volume != null:
return volume();case MixerChannelTargetDto_Pan() when pan != null:
return pan();case MixerChannelTargetDto_Plugin() when plugin != null:
return plugin(_that.effectId,_that.target);case _:
  return null;

}
}

}

/// @nodoc


class MixerChannelTargetDto_Volume extends MixerChannelTargetDto {
  const MixerChannelTargetDto_Volume(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelTargetDto_Volume);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MixerChannelTargetDto.volume()';
}


}




/// @nodoc


class MixerChannelTargetDto_Pan extends MixerChannelTargetDto {
  const MixerChannelTargetDto_Pan(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelTargetDto_Pan);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MixerChannelTargetDto.pan()';
}


}




/// @nodoc


class MixerChannelTargetDto_Plugin extends MixerChannelTargetDto {
  const MixerChannelTargetDto_Plugin({required this.effectId, required this.target}): super._();
  

 final  int effectId;
 final  EffectAutomationTargetDto target;

/// Create a copy of MixerChannelTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MixerChannelTargetDto_PluginCopyWith<MixerChannelTargetDto_Plugin> get copyWith => _$MixerChannelTargetDto_PluginCopyWithImpl<MixerChannelTargetDto_Plugin>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelTargetDto_Plugin&&(identical(other.effectId, effectId) || other.effectId == effectId)&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,effectId,target);

@override
String toString() {
  return 'MixerChannelTargetDto.plugin(effectId: $effectId, target: $target)';
}


}

/// @nodoc
abstract mixin class $MixerChannelTargetDto_PluginCopyWith<$Res> implements $MixerChannelTargetDtoCopyWith<$Res> {
  factory $MixerChannelTargetDto_PluginCopyWith(MixerChannelTargetDto_Plugin value, $Res Function(MixerChannelTargetDto_Plugin) _then) = _$MixerChannelTargetDto_PluginCopyWithImpl;
@useResult
$Res call({
 int effectId, EffectAutomationTargetDto target
});


$EffectAutomationTargetDtoCopyWith<$Res> get target;

}
/// @nodoc
class _$MixerChannelTargetDto_PluginCopyWithImpl<$Res>
    implements $MixerChannelTargetDto_PluginCopyWith<$Res> {
  _$MixerChannelTargetDto_PluginCopyWithImpl(this._self, this._then);

  final MixerChannelTargetDto_Plugin _self;
  final $Res Function(MixerChannelTargetDto_Plugin) _then;

/// Create a copy of MixerChannelTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? effectId = null,Object? target = null,}) {
  return _then(MixerChannelTargetDto_Plugin(
effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as EffectAutomationTargetDto,
  ));
}

/// Create a copy of MixerChannelTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EffectAutomationTargetDtoCopyWith<$Res> get target {
  
  return $EffectAutomationTargetDtoCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

// dart format on
