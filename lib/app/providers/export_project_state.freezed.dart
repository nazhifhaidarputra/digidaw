// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'export_project_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExportProjectStateData {

 String? get exportDirectory; SupportedAudioFormat get selectedFormat; BitDepthDTO get selectedBitDepth; SampleRate get selectedSampleRate; TailHandling get tailHandling; bool get openFolderAfterExport;
/// Create a copy of ExportProjectStateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExportProjectStateDataCopyWith<ExportProjectStateData> get copyWith => _$ExportProjectStateDataCopyWithImpl<ExportProjectStateData>(this as ExportProjectStateData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExportProjectStateData&&(identical(other.exportDirectory, exportDirectory) || other.exportDirectory == exportDirectory)&&(identical(other.selectedFormat, selectedFormat) || other.selectedFormat == selectedFormat)&&(identical(other.selectedBitDepth, selectedBitDepth) || other.selectedBitDepth == selectedBitDepth)&&(identical(other.selectedSampleRate, selectedSampleRate) || other.selectedSampleRate == selectedSampleRate)&&(identical(other.tailHandling, tailHandling) || other.tailHandling == tailHandling)&&(identical(other.openFolderAfterExport, openFolderAfterExport) || other.openFolderAfterExport == openFolderAfterExport));
}


@override
int get hashCode => Object.hash(runtimeType,exportDirectory,selectedFormat,selectedBitDepth,selectedSampleRate,tailHandling,openFolderAfterExport);

@override
String toString() {
  return 'ExportProjectStateData(exportDirectory: $exportDirectory, selectedFormat: $selectedFormat, selectedBitDepth: $selectedBitDepth, selectedSampleRate: $selectedSampleRate, tailHandling: $tailHandling, openFolderAfterExport: $openFolderAfterExport)';
}


}

/// @nodoc
abstract mixin class $ExportProjectStateDataCopyWith<$Res>  {
  factory $ExportProjectStateDataCopyWith(ExportProjectStateData value, $Res Function(ExportProjectStateData) _then) = _$ExportProjectStateDataCopyWithImpl;
@useResult
$Res call({
 String? exportDirectory, SupportedAudioFormat selectedFormat, BitDepthDTO selectedBitDepth, SampleRate selectedSampleRate, TailHandling tailHandling, bool openFolderAfterExport
});


$BitDepthDTOCopyWith<$Res> get selectedBitDepth;

}
/// @nodoc
class _$ExportProjectStateDataCopyWithImpl<$Res>
    implements $ExportProjectStateDataCopyWith<$Res> {
  _$ExportProjectStateDataCopyWithImpl(this._self, this._then);

  final ExportProjectStateData _self;
  final $Res Function(ExportProjectStateData) _then;

/// Create a copy of ExportProjectStateData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? exportDirectory = freezed,Object? selectedFormat = null,Object? selectedBitDepth = null,Object? selectedSampleRate = null,Object? tailHandling = null,Object? openFolderAfterExport = null,}) {
  return _then(_self.copyWith(
exportDirectory: freezed == exportDirectory ? _self.exportDirectory : exportDirectory // ignore: cast_nullable_to_non_nullable
as String?,selectedFormat: null == selectedFormat ? _self.selectedFormat : selectedFormat // ignore: cast_nullable_to_non_nullable
as SupportedAudioFormat,selectedBitDepth: null == selectedBitDepth ? _self.selectedBitDepth : selectedBitDepth // ignore: cast_nullable_to_non_nullable
as BitDepthDTO,selectedSampleRate: null == selectedSampleRate ? _self.selectedSampleRate : selectedSampleRate // ignore: cast_nullable_to_non_nullable
as SampleRate,tailHandling: null == tailHandling ? _self.tailHandling : tailHandling // ignore: cast_nullable_to_non_nullable
as TailHandling,openFolderAfterExport: null == openFolderAfterExport ? _self.openFolderAfterExport : openFolderAfterExport // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ExportProjectStateData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BitDepthDTOCopyWith<$Res> get selectedBitDepth {
  
  return $BitDepthDTOCopyWith<$Res>(_self.selectedBitDepth, (value) {
    return _then(_self.copyWith(selectedBitDepth: value));
  });
}
}


/// Adds pattern-matching-related methods to [ExportProjectStateData].
extension ExportProjectStateDataPatterns on ExportProjectStateData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExportProjectStateData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExportProjectStateData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExportProjectStateData value)  $default,){
final _that = this;
switch (_that) {
case _ExportProjectStateData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExportProjectStateData value)?  $default,){
final _that = this;
switch (_that) {
case _ExportProjectStateData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? exportDirectory,  SupportedAudioFormat selectedFormat,  BitDepthDTO selectedBitDepth,  SampleRate selectedSampleRate,  TailHandling tailHandling,  bool openFolderAfterExport)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExportProjectStateData() when $default != null:
return $default(_that.exportDirectory,_that.selectedFormat,_that.selectedBitDepth,_that.selectedSampleRate,_that.tailHandling,_that.openFolderAfterExport);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? exportDirectory,  SupportedAudioFormat selectedFormat,  BitDepthDTO selectedBitDepth,  SampleRate selectedSampleRate,  TailHandling tailHandling,  bool openFolderAfterExport)  $default,) {final _that = this;
switch (_that) {
case _ExportProjectStateData():
return $default(_that.exportDirectory,_that.selectedFormat,_that.selectedBitDepth,_that.selectedSampleRate,_that.tailHandling,_that.openFolderAfterExport);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? exportDirectory,  SupportedAudioFormat selectedFormat,  BitDepthDTO selectedBitDepth,  SampleRate selectedSampleRate,  TailHandling tailHandling,  bool openFolderAfterExport)?  $default,) {final _that = this;
switch (_that) {
case _ExportProjectStateData() when $default != null:
return $default(_that.exportDirectory,_that.selectedFormat,_that.selectedBitDepth,_that.selectedSampleRate,_that.tailHandling,_that.openFolderAfterExport);case _:
  return null;

}
}

}

/// @nodoc


class _ExportProjectStateData implements ExportProjectStateData {
  const _ExportProjectStateData({this.exportDirectory, this.selectedFormat = SupportedAudioFormat.wav, this.selectedBitDepth = const BitDepthDTO.bitPerSample(16), this.selectedSampleRate = SampleRate.hz44100, this.tailHandling = TailHandling.leaveRemainder, this.openFolderAfterExport = false});
  

@override final  String? exportDirectory;
@override@JsonKey() final  SupportedAudioFormat selectedFormat;
@override@JsonKey() final  BitDepthDTO selectedBitDepth;
@override@JsonKey() final  SampleRate selectedSampleRate;
@override@JsonKey() final  TailHandling tailHandling;
@override@JsonKey() final  bool openFolderAfterExport;

/// Create a copy of ExportProjectStateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExportProjectStateDataCopyWith<_ExportProjectStateData> get copyWith => __$ExportProjectStateDataCopyWithImpl<_ExportProjectStateData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExportProjectStateData&&(identical(other.exportDirectory, exportDirectory) || other.exportDirectory == exportDirectory)&&(identical(other.selectedFormat, selectedFormat) || other.selectedFormat == selectedFormat)&&(identical(other.selectedBitDepth, selectedBitDepth) || other.selectedBitDepth == selectedBitDepth)&&(identical(other.selectedSampleRate, selectedSampleRate) || other.selectedSampleRate == selectedSampleRate)&&(identical(other.tailHandling, tailHandling) || other.tailHandling == tailHandling)&&(identical(other.openFolderAfterExport, openFolderAfterExport) || other.openFolderAfterExport == openFolderAfterExport));
}


@override
int get hashCode => Object.hash(runtimeType,exportDirectory,selectedFormat,selectedBitDepth,selectedSampleRate,tailHandling,openFolderAfterExport);

@override
String toString() {
  return 'ExportProjectStateData(exportDirectory: $exportDirectory, selectedFormat: $selectedFormat, selectedBitDepth: $selectedBitDepth, selectedSampleRate: $selectedSampleRate, tailHandling: $tailHandling, openFolderAfterExport: $openFolderAfterExport)';
}


}

/// @nodoc
abstract mixin class _$ExportProjectStateDataCopyWith<$Res> implements $ExportProjectStateDataCopyWith<$Res> {
  factory _$ExportProjectStateDataCopyWith(_ExportProjectStateData value, $Res Function(_ExportProjectStateData) _then) = __$ExportProjectStateDataCopyWithImpl;
@override @useResult
$Res call({
 String? exportDirectory, SupportedAudioFormat selectedFormat, BitDepthDTO selectedBitDepth, SampleRate selectedSampleRate, TailHandling tailHandling, bool openFolderAfterExport
});


@override $BitDepthDTOCopyWith<$Res> get selectedBitDepth;

}
/// @nodoc
class __$ExportProjectStateDataCopyWithImpl<$Res>
    implements _$ExportProjectStateDataCopyWith<$Res> {
  __$ExportProjectStateDataCopyWithImpl(this._self, this._then);

  final _ExportProjectStateData _self;
  final $Res Function(_ExportProjectStateData) _then;

/// Create a copy of ExportProjectStateData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? exportDirectory = freezed,Object? selectedFormat = null,Object? selectedBitDepth = null,Object? selectedSampleRate = null,Object? tailHandling = null,Object? openFolderAfterExport = null,}) {
  return _then(_ExportProjectStateData(
exportDirectory: freezed == exportDirectory ? _self.exportDirectory : exportDirectory // ignore: cast_nullable_to_non_nullable
as String?,selectedFormat: null == selectedFormat ? _self.selectedFormat : selectedFormat // ignore: cast_nullable_to_non_nullable
as SupportedAudioFormat,selectedBitDepth: null == selectedBitDepth ? _self.selectedBitDepth : selectedBitDepth // ignore: cast_nullable_to_non_nullable
as BitDepthDTO,selectedSampleRate: null == selectedSampleRate ? _self.selectedSampleRate : selectedSampleRate // ignore: cast_nullable_to_non_nullable
as SampleRate,tailHandling: null == tailHandling ? _self.tailHandling : tailHandling // ignore: cast_nullable_to_non_nullable
as TailHandling,openFolderAfterExport: null == openFolderAfterExport ? _self.openFolderAfterExport : openFolderAfterExport // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ExportProjectStateData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BitDepthDTOCopyWith<$Res> get selectedBitDepth {
  
  return $BitDepthDTOCopyWith<$Res>(_self.selectedBitDepth, (value) {
    return _then(_self.copyWith(selectedBitDepth: value));
  });
}
}

// dart format on
