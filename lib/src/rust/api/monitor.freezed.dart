// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monitor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PerformanceMetricsDTO {

 double get osCpuUsage; double get ramUsageMb; double get totalRamMb; double get dspHeadroom;
/// Create a copy of PerformanceMetricsDTO
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PerformanceMetricsDTOCopyWith<PerformanceMetricsDTO> get copyWith => _$PerformanceMetricsDTOCopyWithImpl<PerformanceMetricsDTO>(this as PerformanceMetricsDTO, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PerformanceMetricsDTO&&(identical(other.osCpuUsage, osCpuUsage) || other.osCpuUsage == osCpuUsage)&&(identical(other.ramUsageMb, ramUsageMb) || other.ramUsageMb == ramUsageMb)&&(identical(other.totalRamMb, totalRamMb) || other.totalRamMb == totalRamMb)&&(identical(other.dspHeadroom, dspHeadroom) || other.dspHeadroom == dspHeadroom));
}


@override
int get hashCode => Object.hash(runtimeType,osCpuUsage,ramUsageMb,totalRamMb,dspHeadroom);

@override
String toString() {
  return 'PerformanceMetricsDTO(osCpuUsage: $osCpuUsage, ramUsageMb: $ramUsageMb, totalRamMb: $totalRamMb, dspHeadroom: $dspHeadroom)';
}


}

/// @nodoc
abstract mixin class $PerformanceMetricsDTOCopyWith<$Res>  {
  factory $PerformanceMetricsDTOCopyWith(PerformanceMetricsDTO value, $Res Function(PerformanceMetricsDTO) _then) = _$PerformanceMetricsDTOCopyWithImpl;
@useResult
$Res call({
 double osCpuUsage, double ramUsageMb, double totalRamMb, double dspHeadroom
});




}
/// @nodoc
class _$PerformanceMetricsDTOCopyWithImpl<$Res>
    implements $PerformanceMetricsDTOCopyWith<$Res> {
  _$PerformanceMetricsDTOCopyWithImpl(this._self, this._then);

  final PerformanceMetricsDTO _self;
  final $Res Function(PerformanceMetricsDTO) _then;

/// Create a copy of PerformanceMetricsDTO
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? osCpuUsage = null,Object? ramUsageMb = null,Object? totalRamMb = null,Object? dspHeadroom = null,}) {
  return _then(_self.copyWith(
osCpuUsage: null == osCpuUsage ? _self.osCpuUsage : osCpuUsage // ignore: cast_nullable_to_non_nullable
as double,ramUsageMb: null == ramUsageMb ? _self.ramUsageMb : ramUsageMb // ignore: cast_nullable_to_non_nullable
as double,totalRamMb: null == totalRamMb ? _self.totalRamMb : totalRamMb // ignore: cast_nullable_to_non_nullable
as double,dspHeadroom: null == dspHeadroom ? _self.dspHeadroom : dspHeadroom // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PerformanceMetricsDTO].
extension PerformanceMetricsDTOPatterns on PerformanceMetricsDTO {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PerformanceMetricsDTO value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PerformanceMetricsDTO() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PerformanceMetricsDTO value)  $default,){
final _that = this;
switch (_that) {
case _PerformanceMetricsDTO():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PerformanceMetricsDTO value)?  $default,){
final _that = this;
switch (_that) {
case _PerformanceMetricsDTO() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double osCpuUsage,  double ramUsageMb,  double totalRamMb,  double dspHeadroom)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PerformanceMetricsDTO() when $default != null:
return $default(_that.osCpuUsage,_that.ramUsageMb,_that.totalRamMb,_that.dspHeadroom);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double osCpuUsage,  double ramUsageMb,  double totalRamMb,  double dspHeadroom)  $default,) {final _that = this;
switch (_that) {
case _PerformanceMetricsDTO():
return $default(_that.osCpuUsage,_that.ramUsageMb,_that.totalRamMb,_that.dspHeadroom);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double osCpuUsage,  double ramUsageMb,  double totalRamMb,  double dspHeadroom)?  $default,) {final _that = this;
switch (_that) {
case _PerformanceMetricsDTO() when $default != null:
return $default(_that.osCpuUsage,_that.ramUsageMb,_that.totalRamMb,_that.dspHeadroom);case _:
  return null;

}
}

}

/// @nodoc


class _PerformanceMetricsDTO implements PerformanceMetricsDTO {
  const _PerformanceMetricsDTO({required this.osCpuUsage, required this.ramUsageMb, required this.totalRamMb, required this.dspHeadroom});
  

@override final  double osCpuUsage;
@override final  double ramUsageMb;
@override final  double totalRamMb;
@override final  double dspHeadroom;

/// Create a copy of PerformanceMetricsDTO
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PerformanceMetricsDTOCopyWith<_PerformanceMetricsDTO> get copyWith => __$PerformanceMetricsDTOCopyWithImpl<_PerformanceMetricsDTO>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PerformanceMetricsDTO&&(identical(other.osCpuUsage, osCpuUsage) || other.osCpuUsage == osCpuUsage)&&(identical(other.ramUsageMb, ramUsageMb) || other.ramUsageMb == ramUsageMb)&&(identical(other.totalRamMb, totalRamMb) || other.totalRamMb == totalRamMb)&&(identical(other.dspHeadroom, dspHeadroom) || other.dspHeadroom == dspHeadroom));
}


@override
int get hashCode => Object.hash(runtimeType,osCpuUsage,ramUsageMb,totalRamMb,dspHeadroom);

@override
String toString() {
  return 'PerformanceMetricsDTO(osCpuUsage: $osCpuUsage, ramUsageMb: $ramUsageMb, totalRamMb: $totalRamMb, dspHeadroom: $dspHeadroom)';
}


}

/// @nodoc
abstract mixin class _$PerformanceMetricsDTOCopyWith<$Res> implements $PerformanceMetricsDTOCopyWith<$Res> {
  factory _$PerformanceMetricsDTOCopyWith(_PerformanceMetricsDTO value, $Res Function(_PerformanceMetricsDTO) _then) = __$PerformanceMetricsDTOCopyWithImpl;
@override @useResult
$Res call({
 double osCpuUsage, double ramUsageMb, double totalRamMb, double dspHeadroom
});




}
/// @nodoc
class __$PerformanceMetricsDTOCopyWithImpl<$Res>
    implements _$PerformanceMetricsDTOCopyWith<$Res> {
  __$PerformanceMetricsDTOCopyWithImpl(this._self, this._then);

  final _PerformanceMetricsDTO _self;
  final $Res Function(_PerformanceMetricsDTO) _then;

/// Create a copy of PerformanceMetricsDTO
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? osCpuUsage = null,Object? ramUsageMb = null,Object? totalRamMb = null,Object? dspHeadroom = null,}) {
  return _then(_PerformanceMetricsDTO(
osCpuUsage: null == osCpuUsage ? _self.osCpuUsage : osCpuUsage // ignore: cast_nullable_to_non_nullable
as double,ramUsageMb: null == ramUsageMb ? _self.ramUsageMb : ramUsageMb // ignore: cast_nullable_to_non_nullable
as double,totalRamMb: null == totalRamMb ? _self.totalRamMb : totalRamMb // ignore: cast_nullable_to_non_nullable
as double,dspHeadroom: null == dspHeadroom ? _self.dspHeadroom : dspHeadroom // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
