// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'host_devices_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HostDevicesSettingsState {

 IList<UiAudioHostInfo> get availableHosts; IList<UiOutputDeviceInfo> get availableOutputDevices; IList<UiInputDeviceInfo> get availableInputDevices; String? get selectedHostName; String? get selectedOutputDeviceId;/// Whether the device input is open, so tracks can record and monitor it.
 bool get inputEnabled;/// `null` follows the system default input.
 String? get selectedInputDeviceId; bool get isLoadingInputDevices; bool get isApplyingInput; String? get inputDiscoveryError; bool get isLoadingHosts; bool get isLoadingOutputDevices; bool get isApplyingSelection; bool get isInitialized; String? get discoveryError; String? get fallbackReason; UiAudioRuntimeSettings? get runtimeSettings;
/// Create a copy of HostDevicesSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HostDevicesSettingsStateCopyWith<HostDevicesSettingsState> get copyWith => _$HostDevicesSettingsStateCopyWithImpl<HostDevicesSettingsState>(this as HostDevicesSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostDevicesSettingsState&&const DeepCollectionEquality().equals(other.availableHosts, availableHosts)&&const DeepCollectionEquality().equals(other.availableOutputDevices, availableOutputDevices)&&const DeepCollectionEquality().equals(other.availableInputDevices, availableInputDevices)&&(identical(other.selectedHostName, selectedHostName) || other.selectedHostName == selectedHostName)&&(identical(other.selectedOutputDeviceId, selectedOutputDeviceId) || other.selectedOutputDeviceId == selectedOutputDeviceId)&&(identical(other.inputEnabled, inputEnabled) || other.inputEnabled == inputEnabled)&&(identical(other.selectedInputDeviceId, selectedInputDeviceId) || other.selectedInputDeviceId == selectedInputDeviceId)&&(identical(other.isLoadingInputDevices, isLoadingInputDevices) || other.isLoadingInputDevices == isLoadingInputDevices)&&(identical(other.isApplyingInput, isApplyingInput) || other.isApplyingInput == isApplyingInput)&&(identical(other.inputDiscoveryError, inputDiscoveryError) || other.inputDiscoveryError == inputDiscoveryError)&&(identical(other.isLoadingHosts, isLoadingHosts) || other.isLoadingHosts == isLoadingHosts)&&(identical(other.isLoadingOutputDevices, isLoadingOutputDevices) || other.isLoadingOutputDevices == isLoadingOutputDevices)&&(identical(other.isApplyingSelection, isApplyingSelection) || other.isApplyingSelection == isApplyingSelection)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.discoveryError, discoveryError) || other.discoveryError == discoveryError)&&(identical(other.fallbackReason, fallbackReason) || other.fallbackReason == fallbackReason)&&(identical(other.runtimeSettings, runtimeSettings) || other.runtimeSettings == runtimeSettings));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(availableHosts),const DeepCollectionEquality().hash(availableOutputDevices),const DeepCollectionEquality().hash(availableInputDevices),selectedHostName,selectedOutputDeviceId,inputEnabled,selectedInputDeviceId,isLoadingInputDevices,isApplyingInput,inputDiscoveryError,isLoadingHosts,isLoadingOutputDevices,isApplyingSelection,isInitialized,discoveryError,fallbackReason,runtimeSettings);

@override
String toString() {
  return 'HostDevicesSettingsState(availableHosts: $availableHosts, availableOutputDevices: $availableOutputDevices, availableInputDevices: $availableInputDevices, selectedHostName: $selectedHostName, selectedOutputDeviceId: $selectedOutputDeviceId, inputEnabled: $inputEnabled, selectedInputDeviceId: $selectedInputDeviceId, isLoadingInputDevices: $isLoadingInputDevices, isApplyingInput: $isApplyingInput, inputDiscoveryError: $inputDiscoveryError, isLoadingHosts: $isLoadingHosts, isLoadingOutputDevices: $isLoadingOutputDevices, isApplyingSelection: $isApplyingSelection, isInitialized: $isInitialized, discoveryError: $discoveryError, fallbackReason: $fallbackReason, runtimeSettings: $runtimeSettings)';
}


}

/// @nodoc
abstract mixin class $HostDevicesSettingsStateCopyWith<$Res>  {
  factory $HostDevicesSettingsStateCopyWith(HostDevicesSettingsState value, $Res Function(HostDevicesSettingsState) _then) = _$HostDevicesSettingsStateCopyWithImpl;
@useResult
$Res call({
 IList<UiAudioHostInfo> availableHosts, IList<UiOutputDeviceInfo> availableOutputDevices, IList<UiInputDeviceInfo> availableInputDevices, String? selectedHostName, String? selectedOutputDeviceId, bool inputEnabled, String? selectedInputDeviceId, bool isLoadingInputDevices, bool isApplyingInput, String? inputDiscoveryError, bool isLoadingHosts, bool isLoadingOutputDevices, bool isApplyingSelection, bool isInitialized, String? discoveryError, String? fallbackReason, UiAudioRuntimeSettings? runtimeSettings
});


$UiAudioRuntimeSettingsCopyWith<$Res>? get runtimeSettings;

}
/// @nodoc
class _$HostDevicesSettingsStateCopyWithImpl<$Res>
    implements $HostDevicesSettingsStateCopyWith<$Res> {
  _$HostDevicesSettingsStateCopyWithImpl(this._self, this._then);

  final HostDevicesSettingsState _self;
  final $Res Function(HostDevicesSettingsState) _then;

/// Create a copy of HostDevicesSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? availableHosts = null,Object? availableOutputDevices = null,Object? availableInputDevices = null,Object? selectedHostName = freezed,Object? selectedOutputDeviceId = freezed,Object? inputEnabled = null,Object? selectedInputDeviceId = freezed,Object? isLoadingInputDevices = null,Object? isApplyingInput = null,Object? inputDiscoveryError = freezed,Object? isLoadingHosts = null,Object? isLoadingOutputDevices = null,Object? isApplyingSelection = null,Object? isInitialized = null,Object? discoveryError = freezed,Object? fallbackReason = freezed,Object? runtimeSettings = freezed,}) {
  return _then(_self.copyWith(
availableHosts: null == availableHosts ? _self.availableHosts : availableHosts // ignore: cast_nullable_to_non_nullable
as IList<UiAudioHostInfo>,availableOutputDevices: null == availableOutputDevices ? _self.availableOutputDevices : availableOutputDevices // ignore: cast_nullable_to_non_nullable
as IList<UiOutputDeviceInfo>,availableInputDevices: null == availableInputDevices ? _self.availableInputDevices : availableInputDevices // ignore: cast_nullable_to_non_nullable
as IList<UiInputDeviceInfo>,selectedHostName: freezed == selectedHostName ? _self.selectedHostName : selectedHostName // ignore: cast_nullable_to_non_nullable
as String?,selectedOutputDeviceId: freezed == selectedOutputDeviceId ? _self.selectedOutputDeviceId : selectedOutputDeviceId // ignore: cast_nullable_to_non_nullable
as String?,inputEnabled: null == inputEnabled ? _self.inputEnabled : inputEnabled // ignore: cast_nullable_to_non_nullable
as bool,selectedInputDeviceId: freezed == selectedInputDeviceId ? _self.selectedInputDeviceId : selectedInputDeviceId // ignore: cast_nullable_to_non_nullable
as String?,isLoadingInputDevices: null == isLoadingInputDevices ? _self.isLoadingInputDevices : isLoadingInputDevices // ignore: cast_nullable_to_non_nullable
as bool,isApplyingInput: null == isApplyingInput ? _self.isApplyingInput : isApplyingInput // ignore: cast_nullable_to_non_nullable
as bool,inputDiscoveryError: freezed == inputDiscoveryError ? _self.inputDiscoveryError : inputDiscoveryError // ignore: cast_nullable_to_non_nullable
as String?,isLoadingHosts: null == isLoadingHosts ? _self.isLoadingHosts : isLoadingHosts // ignore: cast_nullable_to_non_nullable
as bool,isLoadingOutputDevices: null == isLoadingOutputDevices ? _self.isLoadingOutputDevices : isLoadingOutputDevices // ignore: cast_nullable_to_non_nullable
as bool,isApplyingSelection: null == isApplyingSelection ? _self.isApplyingSelection : isApplyingSelection // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,discoveryError: freezed == discoveryError ? _self.discoveryError : discoveryError // ignore: cast_nullable_to_non_nullable
as String?,fallbackReason: freezed == fallbackReason ? _self.fallbackReason : fallbackReason // ignore: cast_nullable_to_non_nullable
as String?,runtimeSettings: freezed == runtimeSettings ? _self.runtimeSettings : runtimeSettings // ignore: cast_nullable_to_non_nullable
as UiAudioRuntimeSettings?,
  ));
}
/// Create a copy of HostDevicesSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiAudioRuntimeSettingsCopyWith<$Res>? get runtimeSettings {
    if (_self.runtimeSettings == null) {
    return null;
  }

  return $UiAudioRuntimeSettingsCopyWith<$Res>(_self.runtimeSettings!, (value) {
    return _then(_self.copyWith(runtimeSettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [HostDevicesSettingsState].
extension HostDevicesSettingsStatePatterns on HostDevicesSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HostDevicesSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HostDevicesSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HostDevicesSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _HostDevicesSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HostDevicesSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _HostDevicesSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IList<UiAudioHostInfo> availableHosts,  IList<UiOutputDeviceInfo> availableOutputDevices,  IList<UiInputDeviceInfo> availableInputDevices,  String? selectedHostName,  String? selectedOutputDeviceId,  bool inputEnabled,  String? selectedInputDeviceId,  bool isLoadingInputDevices,  bool isApplyingInput,  String? inputDiscoveryError,  bool isLoadingHosts,  bool isLoadingOutputDevices,  bool isApplyingSelection,  bool isInitialized,  String? discoveryError,  String? fallbackReason,  UiAudioRuntimeSettings? runtimeSettings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HostDevicesSettingsState() when $default != null:
return $default(_that.availableHosts,_that.availableOutputDevices,_that.availableInputDevices,_that.selectedHostName,_that.selectedOutputDeviceId,_that.inputEnabled,_that.selectedInputDeviceId,_that.isLoadingInputDevices,_that.isApplyingInput,_that.inputDiscoveryError,_that.isLoadingHosts,_that.isLoadingOutputDevices,_that.isApplyingSelection,_that.isInitialized,_that.discoveryError,_that.fallbackReason,_that.runtimeSettings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IList<UiAudioHostInfo> availableHosts,  IList<UiOutputDeviceInfo> availableOutputDevices,  IList<UiInputDeviceInfo> availableInputDevices,  String? selectedHostName,  String? selectedOutputDeviceId,  bool inputEnabled,  String? selectedInputDeviceId,  bool isLoadingInputDevices,  bool isApplyingInput,  String? inputDiscoveryError,  bool isLoadingHosts,  bool isLoadingOutputDevices,  bool isApplyingSelection,  bool isInitialized,  String? discoveryError,  String? fallbackReason,  UiAudioRuntimeSettings? runtimeSettings)  $default,) {final _that = this;
switch (_that) {
case _HostDevicesSettingsState():
return $default(_that.availableHosts,_that.availableOutputDevices,_that.availableInputDevices,_that.selectedHostName,_that.selectedOutputDeviceId,_that.inputEnabled,_that.selectedInputDeviceId,_that.isLoadingInputDevices,_that.isApplyingInput,_that.inputDiscoveryError,_that.isLoadingHosts,_that.isLoadingOutputDevices,_that.isApplyingSelection,_that.isInitialized,_that.discoveryError,_that.fallbackReason,_that.runtimeSettings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IList<UiAudioHostInfo> availableHosts,  IList<UiOutputDeviceInfo> availableOutputDevices,  IList<UiInputDeviceInfo> availableInputDevices,  String? selectedHostName,  String? selectedOutputDeviceId,  bool inputEnabled,  String? selectedInputDeviceId,  bool isLoadingInputDevices,  bool isApplyingInput,  String? inputDiscoveryError,  bool isLoadingHosts,  bool isLoadingOutputDevices,  bool isApplyingSelection,  bool isInitialized,  String? discoveryError,  String? fallbackReason,  UiAudioRuntimeSettings? runtimeSettings)?  $default,) {final _that = this;
switch (_that) {
case _HostDevicesSettingsState() when $default != null:
return $default(_that.availableHosts,_that.availableOutputDevices,_that.availableInputDevices,_that.selectedHostName,_that.selectedOutputDeviceId,_that.inputEnabled,_that.selectedInputDeviceId,_that.isLoadingInputDevices,_that.isApplyingInput,_that.inputDiscoveryError,_that.isLoadingHosts,_that.isLoadingOutputDevices,_that.isApplyingSelection,_that.isInitialized,_that.discoveryError,_that.fallbackReason,_that.runtimeSettings);case _:
  return null;

}
}

}

/// @nodoc


class _HostDevicesSettingsState implements HostDevicesSettingsState {
  const _HostDevicesSettingsState({this.availableHosts = const IListConst<UiAudioHostInfo>([]), this.availableOutputDevices = const IListConst<UiOutputDeviceInfo>([]), this.availableInputDevices = const IListConst<UiInputDeviceInfo>([]), this.selectedHostName, this.selectedOutputDeviceId, this.inputEnabled = false, this.selectedInputDeviceId, this.isLoadingInputDevices = false, this.isApplyingInput = false, this.inputDiscoveryError, this.isLoadingHosts = false, this.isLoadingOutputDevices = false, this.isApplyingSelection = false, this.isInitialized = false, this.discoveryError, this.fallbackReason, this.runtimeSettings});
  

@override@JsonKey() final  IList<UiAudioHostInfo> availableHosts;
@override@JsonKey() final  IList<UiOutputDeviceInfo> availableOutputDevices;
@override@JsonKey() final  IList<UiInputDeviceInfo> availableInputDevices;
@override final  String? selectedHostName;
@override final  String? selectedOutputDeviceId;
/// Whether the device input is open, so tracks can record and monitor it.
@override@JsonKey() final  bool inputEnabled;
/// `null` follows the system default input.
@override final  String? selectedInputDeviceId;
@override@JsonKey() final  bool isLoadingInputDevices;
@override@JsonKey() final  bool isApplyingInput;
@override final  String? inputDiscoveryError;
@override@JsonKey() final  bool isLoadingHosts;
@override@JsonKey() final  bool isLoadingOutputDevices;
@override@JsonKey() final  bool isApplyingSelection;
@override@JsonKey() final  bool isInitialized;
@override final  String? discoveryError;
@override final  String? fallbackReason;
@override final  UiAudioRuntimeSettings? runtimeSettings;

/// Create a copy of HostDevicesSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HostDevicesSettingsStateCopyWith<_HostDevicesSettingsState> get copyWith => __$HostDevicesSettingsStateCopyWithImpl<_HostDevicesSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HostDevicesSettingsState&&const DeepCollectionEquality().equals(other.availableHosts, availableHosts)&&const DeepCollectionEquality().equals(other.availableOutputDevices, availableOutputDevices)&&const DeepCollectionEquality().equals(other.availableInputDevices, availableInputDevices)&&(identical(other.selectedHostName, selectedHostName) || other.selectedHostName == selectedHostName)&&(identical(other.selectedOutputDeviceId, selectedOutputDeviceId) || other.selectedOutputDeviceId == selectedOutputDeviceId)&&(identical(other.inputEnabled, inputEnabled) || other.inputEnabled == inputEnabled)&&(identical(other.selectedInputDeviceId, selectedInputDeviceId) || other.selectedInputDeviceId == selectedInputDeviceId)&&(identical(other.isLoadingInputDevices, isLoadingInputDevices) || other.isLoadingInputDevices == isLoadingInputDevices)&&(identical(other.isApplyingInput, isApplyingInput) || other.isApplyingInput == isApplyingInput)&&(identical(other.inputDiscoveryError, inputDiscoveryError) || other.inputDiscoveryError == inputDiscoveryError)&&(identical(other.isLoadingHosts, isLoadingHosts) || other.isLoadingHosts == isLoadingHosts)&&(identical(other.isLoadingOutputDevices, isLoadingOutputDevices) || other.isLoadingOutputDevices == isLoadingOutputDevices)&&(identical(other.isApplyingSelection, isApplyingSelection) || other.isApplyingSelection == isApplyingSelection)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.discoveryError, discoveryError) || other.discoveryError == discoveryError)&&(identical(other.fallbackReason, fallbackReason) || other.fallbackReason == fallbackReason)&&(identical(other.runtimeSettings, runtimeSettings) || other.runtimeSettings == runtimeSettings));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(availableHosts),const DeepCollectionEquality().hash(availableOutputDevices),const DeepCollectionEquality().hash(availableInputDevices),selectedHostName,selectedOutputDeviceId,inputEnabled,selectedInputDeviceId,isLoadingInputDevices,isApplyingInput,inputDiscoveryError,isLoadingHosts,isLoadingOutputDevices,isApplyingSelection,isInitialized,discoveryError,fallbackReason,runtimeSettings);

@override
String toString() {
  return 'HostDevicesSettingsState(availableHosts: $availableHosts, availableOutputDevices: $availableOutputDevices, availableInputDevices: $availableInputDevices, selectedHostName: $selectedHostName, selectedOutputDeviceId: $selectedOutputDeviceId, inputEnabled: $inputEnabled, selectedInputDeviceId: $selectedInputDeviceId, isLoadingInputDevices: $isLoadingInputDevices, isApplyingInput: $isApplyingInput, inputDiscoveryError: $inputDiscoveryError, isLoadingHosts: $isLoadingHosts, isLoadingOutputDevices: $isLoadingOutputDevices, isApplyingSelection: $isApplyingSelection, isInitialized: $isInitialized, discoveryError: $discoveryError, fallbackReason: $fallbackReason, runtimeSettings: $runtimeSettings)';
}


}

/// @nodoc
abstract mixin class _$HostDevicesSettingsStateCopyWith<$Res> implements $HostDevicesSettingsStateCopyWith<$Res> {
  factory _$HostDevicesSettingsStateCopyWith(_HostDevicesSettingsState value, $Res Function(_HostDevicesSettingsState) _then) = __$HostDevicesSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 IList<UiAudioHostInfo> availableHosts, IList<UiOutputDeviceInfo> availableOutputDevices, IList<UiInputDeviceInfo> availableInputDevices, String? selectedHostName, String? selectedOutputDeviceId, bool inputEnabled, String? selectedInputDeviceId, bool isLoadingInputDevices, bool isApplyingInput, String? inputDiscoveryError, bool isLoadingHosts, bool isLoadingOutputDevices, bool isApplyingSelection, bool isInitialized, String? discoveryError, String? fallbackReason, UiAudioRuntimeSettings? runtimeSettings
});


@override $UiAudioRuntimeSettingsCopyWith<$Res>? get runtimeSettings;

}
/// @nodoc
class __$HostDevicesSettingsStateCopyWithImpl<$Res>
    implements _$HostDevicesSettingsStateCopyWith<$Res> {
  __$HostDevicesSettingsStateCopyWithImpl(this._self, this._then);

  final _HostDevicesSettingsState _self;
  final $Res Function(_HostDevicesSettingsState) _then;

/// Create a copy of HostDevicesSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? availableHosts = null,Object? availableOutputDevices = null,Object? availableInputDevices = null,Object? selectedHostName = freezed,Object? selectedOutputDeviceId = freezed,Object? inputEnabled = null,Object? selectedInputDeviceId = freezed,Object? isLoadingInputDevices = null,Object? isApplyingInput = null,Object? inputDiscoveryError = freezed,Object? isLoadingHosts = null,Object? isLoadingOutputDevices = null,Object? isApplyingSelection = null,Object? isInitialized = null,Object? discoveryError = freezed,Object? fallbackReason = freezed,Object? runtimeSettings = freezed,}) {
  return _then(_HostDevicesSettingsState(
availableHosts: null == availableHosts ? _self.availableHosts : availableHosts // ignore: cast_nullable_to_non_nullable
as IList<UiAudioHostInfo>,availableOutputDevices: null == availableOutputDevices ? _self.availableOutputDevices : availableOutputDevices // ignore: cast_nullable_to_non_nullable
as IList<UiOutputDeviceInfo>,availableInputDevices: null == availableInputDevices ? _self.availableInputDevices : availableInputDevices // ignore: cast_nullable_to_non_nullable
as IList<UiInputDeviceInfo>,selectedHostName: freezed == selectedHostName ? _self.selectedHostName : selectedHostName // ignore: cast_nullable_to_non_nullable
as String?,selectedOutputDeviceId: freezed == selectedOutputDeviceId ? _self.selectedOutputDeviceId : selectedOutputDeviceId // ignore: cast_nullable_to_non_nullable
as String?,inputEnabled: null == inputEnabled ? _self.inputEnabled : inputEnabled // ignore: cast_nullable_to_non_nullable
as bool,selectedInputDeviceId: freezed == selectedInputDeviceId ? _self.selectedInputDeviceId : selectedInputDeviceId // ignore: cast_nullable_to_non_nullable
as String?,isLoadingInputDevices: null == isLoadingInputDevices ? _self.isLoadingInputDevices : isLoadingInputDevices // ignore: cast_nullable_to_non_nullable
as bool,isApplyingInput: null == isApplyingInput ? _self.isApplyingInput : isApplyingInput // ignore: cast_nullable_to_non_nullable
as bool,inputDiscoveryError: freezed == inputDiscoveryError ? _self.inputDiscoveryError : inputDiscoveryError // ignore: cast_nullable_to_non_nullable
as String?,isLoadingHosts: null == isLoadingHosts ? _self.isLoadingHosts : isLoadingHosts // ignore: cast_nullable_to_non_nullable
as bool,isLoadingOutputDevices: null == isLoadingOutputDevices ? _self.isLoadingOutputDevices : isLoadingOutputDevices // ignore: cast_nullable_to_non_nullable
as bool,isApplyingSelection: null == isApplyingSelection ? _self.isApplyingSelection : isApplyingSelection // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,discoveryError: freezed == discoveryError ? _self.discoveryError : discoveryError // ignore: cast_nullable_to_non_nullable
as String?,fallbackReason: freezed == fallbackReason ? _self.fallbackReason : fallbackReason // ignore: cast_nullable_to_non_nullable
as String?,runtimeSettings: freezed == runtimeSettings ? _self.runtimeSettings : runtimeSettings // ignore: cast_nullable_to_non_nullable
as UiAudioRuntimeSettings?,
  ));
}

/// Create a copy of HostDevicesSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiAudioRuntimeSettingsCopyWith<$Res>? get runtimeSettings {
    if (_self.runtimeSettings == null) {
    return null;
  }

  return $UiAudioRuntimeSettingsCopyWith<$Res>(_self.runtimeSettings!, (value) {
    return _then(_self.copyWith(runtimeSettings: value));
  });
}
}

// dart format on
