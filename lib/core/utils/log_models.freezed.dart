// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'log_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppLogEntry {

 int get sequence; DateTime get timestamp; AppLogLevel get level; String get message; String? get errorSummary;
/// Create a copy of AppLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppLogEntryCopyWith<AppLogEntry> get copyWith => _$AppLogEntryCopyWithImpl<AppLogEntry>(this as AppLogEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppLogEntry&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.level, level) || other.level == level)&&(identical(other.message, message) || other.message == message)&&(identical(other.errorSummary, errorSummary) || other.errorSummary == errorSummary));
}


@override
int get hashCode => Object.hash(runtimeType,sequence,timestamp,level,message,errorSummary);

@override
String toString() {
  return 'AppLogEntry(sequence: $sequence, timestamp: $timestamp, level: $level, message: $message, errorSummary: $errorSummary)';
}


}

/// @nodoc
abstract mixin class $AppLogEntryCopyWith<$Res>  {
  factory $AppLogEntryCopyWith(AppLogEntry value, $Res Function(AppLogEntry) _then) = _$AppLogEntryCopyWithImpl;
@useResult
$Res call({
 int sequence, DateTime timestamp, AppLogLevel level, String message, String? errorSummary
});




}
/// @nodoc
class _$AppLogEntryCopyWithImpl<$Res>
    implements $AppLogEntryCopyWith<$Res> {
  _$AppLogEntryCopyWithImpl(this._self, this._then);

  final AppLogEntry _self;
  final $Res Function(AppLogEntry) _then;

/// Create a copy of AppLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sequence = null,Object? timestamp = null,Object? level = null,Object? message = null,Object? errorSummary = freezed,}) {
  return _then(_self.copyWith(
sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as AppLogLevel,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,errorSummary: freezed == errorSummary ? _self.errorSummary : errorSummary // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppLogEntry].
extension AppLogEntryPatterns on AppLogEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppLogEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppLogEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppLogEntry value)  $default,){
final _that = this;
switch (_that) {
case _AppLogEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppLogEntry value)?  $default,){
final _that = this;
switch (_that) {
case _AppLogEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sequence,  DateTime timestamp,  AppLogLevel level,  String message,  String? errorSummary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppLogEntry() when $default != null:
return $default(_that.sequence,_that.timestamp,_that.level,_that.message,_that.errorSummary);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sequence,  DateTime timestamp,  AppLogLevel level,  String message,  String? errorSummary)  $default,) {final _that = this;
switch (_that) {
case _AppLogEntry():
return $default(_that.sequence,_that.timestamp,_that.level,_that.message,_that.errorSummary);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sequence,  DateTime timestamp,  AppLogLevel level,  String message,  String? errorSummary)?  $default,) {final _that = this;
switch (_that) {
case _AppLogEntry() when $default != null:
return $default(_that.sequence,_that.timestamp,_that.level,_that.message,_that.errorSummary);case _:
  return null;

}
}

}

/// @nodoc


class _AppLogEntry implements AppLogEntry {
  const _AppLogEntry({required this.sequence, required this.timestamp, required this.level, required this.message, this.errorSummary});
  

@override final  int sequence;
@override final  DateTime timestamp;
@override final  AppLogLevel level;
@override final  String message;
@override final  String? errorSummary;

/// Create a copy of AppLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppLogEntryCopyWith<_AppLogEntry> get copyWith => __$AppLogEntryCopyWithImpl<_AppLogEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppLogEntry&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.level, level) || other.level == level)&&(identical(other.message, message) || other.message == message)&&(identical(other.errorSummary, errorSummary) || other.errorSummary == errorSummary));
}


@override
int get hashCode => Object.hash(runtimeType,sequence,timestamp,level,message,errorSummary);

@override
String toString() {
  return 'AppLogEntry(sequence: $sequence, timestamp: $timestamp, level: $level, message: $message, errorSummary: $errorSummary)';
}


}

/// @nodoc
abstract mixin class _$AppLogEntryCopyWith<$Res> implements $AppLogEntryCopyWith<$Res> {
  factory _$AppLogEntryCopyWith(_AppLogEntry value, $Res Function(_AppLogEntry) _then) = __$AppLogEntryCopyWithImpl;
@override @useResult
$Res call({
 int sequence, DateTime timestamp, AppLogLevel level, String message, String? errorSummary
});




}
/// @nodoc
class __$AppLogEntryCopyWithImpl<$Res>
    implements _$AppLogEntryCopyWith<$Res> {
  __$AppLogEntryCopyWithImpl(this._self, this._then);

  final _AppLogEntry _self;
  final $Res Function(_AppLogEntry) _then;

/// Create a copy of AppLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sequence = null,Object? timestamp = null,Object? level = null,Object? message = null,Object? errorSummary = freezed,}) {
  return _then(_AppLogEntry(
sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as AppLogLevel,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,errorSummary: freezed == errorSummary ? _self.errorSummary : errorSummary // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$AppLogState {

 IList<AppLogEntry> get entries; AppLogLevel get minimumLevel; int get maximumEntries; bool get isInitialized;
/// Create a copy of AppLogState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppLogStateCopyWith<AppLogState> get copyWith => _$AppLogStateCopyWithImpl<AppLogState>(this as AppLogState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppLogState&&const DeepCollectionEquality().equals(other.entries, entries)&&(identical(other.minimumLevel, minimumLevel) || other.minimumLevel == minimumLevel)&&(identical(other.maximumEntries, maximumEntries) || other.maximumEntries == maximumEntries)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(entries),minimumLevel,maximumEntries,isInitialized);

@override
String toString() {
  return 'AppLogState(entries: $entries, minimumLevel: $minimumLevel, maximumEntries: $maximumEntries, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class $AppLogStateCopyWith<$Res>  {
  factory $AppLogStateCopyWith(AppLogState value, $Res Function(AppLogState) _then) = _$AppLogStateCopyWithImpl;
@useResult
$Res call({
 IList<AppLogEntry> entries, AppLogLevel minimumLevel, int maximumEntries, bool isInitialized
});




}
/// @nodoc
class _$AppLogStateCopyWithImpl<$Res>
    implements $AppLogStateCopyWith<$Res> {
  _$AppLogStateCopyWithImpl(this._self, this._then);

  final AppLogState _self;
  final $Res Function(AppLogState) _then;

/// Create a copy of AppLogState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entries = null,Object? minimumLevel = null,Object? maximumEntries = null,Object? isInitialized = null,}) {
  return _then(_self.copyWith(
entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as IList<AppLogEntry>,minimumLevel: null == minimumLevel ? _self.minimumLevel : minimumLevel // ignore: cast_nullable_to_non_nullable
as AppLogLevel,maximumEntries: null == maximumEntries ? _self.maximumEntries : maximumEntries // ignore: cast_nullable_to_non_nullable
as int,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppLogState].
extension AppLogStatePatterns on AppLogState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppLogState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppLogState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppLogState value)  $default,){
final _that = this;
switch (_that) {
case _AppLogState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppLogState value)?  $default,){
final _that = this;
switch (_that) {
case _AppLogState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IList<AppLogEntry> entries,  AppLogLevel minimumLevel,  int maximumEntries,  bool isInitialized)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppLogState() when $default != null:
return $default(_that.entries,_that.minimumLevel,_that.maximumEntries,_that.isInitialized);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IList<AppLogEntry> entries,  AppLogLevel minimumLevel,  int maximumEntries,  bool isInitialized)  $default,) {final _that = this;
switch (_that) {
case _AppLogState():
return $default(_that.entries,_that.minimumLevel,_that.maximumEntries,_that.isInitialized);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IList<AppLogEntry> entries,  AppLogLevel minimumLevel,  int maximumEntries,  bool isInitialized)?  $default,) {final _that = this;
switch (_that) {
case _AppLogState() when $default != null:
return $default(_that.entries,_that.minimumLevel,_that.maximumEntries,_that.isInitialized);case _:
  return null;

}
}

}

/// @nodoc


class _AppLogState implements AppLogState {
  const _AppLogState({this.entries = const IListConst<AppLogEntry>([]), this.minimumLevel = AppLogLevel.info, this.maximumEntries = 250, this.isInitialized = false});
  

@override@JsonKey() final  IList<AppLogEntry> entries;
@override@JsonKey() final  AppLogLevel minimumLevel;
@override@JsonKey() final  int maximumEntries;
@override@JsonKey() final  bool isInitialized;

/// Create a copy of AppLogState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppLogStateCopyWith<_AppLogState> get copyWith => __$AppLogStateCopyWithImpl<_AppLogState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppLogState&&const DeepCollectionEquality().equals(other.entries, entries)&&(identical(other.minimumLevel, minimumLevel) || other.minimumLevel == minimumLevel)&&(identical(other.maximumEntries, maximumEntries) || other.maximumEntries == maximumEntries)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(entries),minimumLevel,maximumEntries,isInitialized);

@override
String toString() {
  return 'AppLogState(entries: $entries, minimumLevel: $minimumLevel, maximumEntries: $maximumEntries, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class _$AppLogStateCopyWith<$Res> implements $AppLogStateCopyWith<$Res> {
  factory _$AppLogStateCopyWith(_AppLogState value, $Res Function(_AppLogState) _then) = __$AppLogStateCopyWithImpl;
@override @useResult
$Res call({
 IList<AppLogEntry> entries, AppLogLevel minimumLevel, int maximumEntries, bool isInitialized
});




}
/// @nodoc
class __$AppLogStateCopyWithImpl<$Res>
    implements _$AppLogStateCopyWith<$Res> {
  __$AppLogStateCopyWithImpl(this._self, this._then);

  final _AppLogState _self;
  final $Res Function(_AppLogState) _then;

/// Create a copy of AppLogState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entries = null,Object? minimumLevel = null,Object? maximumEntries = null,Object? isInitialized = null,}) {
  return _then(_AppLogState(
entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as IList<AppLogEntry>,minimumLevel: null == minimumLevel ? _self.minimumLevel : minimumLevel // ignore: cast_nullable_to_non_nullable
as AppLogLevel,maximumEntries: null == maximumEntries ? _self.maximumEntries : maximumEntries // ignore: cast_nullable_to_non_nullable
as int,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
