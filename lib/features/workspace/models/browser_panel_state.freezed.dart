// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'browser_panel_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BrowserSample {

 String get name; String get path;
/// Create a copy of BrowserSample
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BrowserSampleCopyWith<BrowserSample> get copyWith => _$BrowserSampleCopyWithImpl<BrowserSample>(this as BrowserSample, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BrowserSample&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,name,path);

@override
String toString() {
  return 'BrowserSample(name: $name, path: $path)';
}


}

/// @nodoc
abstract mixin class $BrowserSampleCopyWith<$Res>  {
  factory $BrowserSampleCopyWith(BrowserSample value, $Res Function(BrowserSample) _then) = _$BrowserSampleCopyWithImpl;
@useResult
$Res call({
 String name, String path
});




}
/// @nodoc
class _$BrowserSampleCopyWithImpl<$Res>
    implements $BrowserSampleCopyWith<$Res> {
  _$BrowserSampleCopyWithImpl(this._self, this._then);

  final BrowserSample _self;
  final $Res Function(BrowserSample) _then;

/// Create a copy of BrowserSample
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? path = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BrowserSample].
extension BrowserSamplePatterns on BrowserSample {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BrowserSample value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BrowserSample() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BrowserSample value)  $default,){
final _that = this;
switch (_that) {
case _BrowserSample():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BrowserSample value)?  $default,){
final _that = this;
switch (_that) {
case _BrowserSample() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BrowserSample() when $default != null:
return $default(_that.name,_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String path)  $default,) {final _that = this;
switch (_that) {
case _BrowserSample():
return $default(_that.name,_that.path);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String path)?  $default,) {final _that = this;
switch (_that) {
case _BrowserSample() when $default != null:
return $default(_that.name,_that.path);case _:
  return null;

}
}

}

/// @nodoc


class _BrowserSample implements BrowserSample {
  const _BrowserSample({required this.name, required this.path});
  

@override final  String name;
@override final  String path;

/// Create a copy of BrowserSample
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BrowserSampleCopyWith<_BrowserSample> get copyWith => __$BrowserSampleCopyWithImpl<_BrowserSample>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BrowserSample&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,name,path);

@override
String toString() {
  return 'BrowserSample(name: $name, path: $path)';
}


}

/// @nodoc
abstract mixin class _$BrowserSampleCopyWith<$Res> implements $BrowserSampleCopyWith<$Res> {
  factory _$BrowserSampleCopyWith(_BrowserSample value, $Res Function(_BrowserSample) _then) = __$BrowserSampleCopyWithImpl;
@override @useResult
$Res call({
 String name, String path
});




}
/// @nodoc
class __$BrowserSampleCopyWithImpl<$Res>
    implements _$BrowserSampleCopyWith<$Res> {
  __$BrowserSampleCopyWithImpl(this._self, this._then);

  final _BrowserSample _self;
  final $Res Function(_BrowserSample) _then;

/// Create a copy of BrowserSample
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = null,}) {
  return _then(_BrowserSample(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$FileTree {

 String get name; String get path; IList<FileTree> get directories; IList<BrowserSample> get samples;
/// Create a copy of FileTree
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileTreeCopyWith<FileTree> get copyWith => _$FileTreeCopyWithImpl<FileTree>(this as FileTree, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTree&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.directories, directories)&&const DeepCollectionEquality().equals(other.samples, samples));
}


@override
int get hashCode => Object.hash(runtimeType,name,path,const DeepCollectionEquality().hash(directories),const DeepCollectionEquality().hash(samples));

@override
String toString() {
  return 'FileTree(name: $name, path: $path, directories: $directories, samples: $samples)';
}


}

/// @nodoc
abstract mixin class $FileTreeCopyWith<$Res>  {
  factory $FileTreeCopyWith(FileTree value, $Res Function(FileTree) _then) = _$FileTreeCopyWithImpl;
@useResult
$Res call({
 String name, String path, IList<FileTree> directories, IList<BrowserSample> samples
});




}
/// @nodoc
class _$FileTreeCopyWithImpl<$Res>
    implements $FileTreeCopyWith<$Res> {
  _$FileTreeCopyWithImpl(this._self, this._then);

  final FileTree _self;
  final $Res Function(FileTree) _then;

/// Create a copy of FileTree
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? path = null,Object? directories = null,Object? samples = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,directories: null == directories ? _self.directories : directories // ignore: cast_nullable_to_non_nullable
as IList<FileTree>,samples: null == samples ? _self.samples : samples // ignore: cast_nullable_to_non_nullable
as IList<BrowserSample>,
  ));
}

}


/// Adds pattern-matching-related methods to [FileTree].
extension FileTreePatterns on FileTree {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileTree value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileTree() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileTree value)  $default,){
final _that = this;
switch (_that) {
case _FileTree():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileTree value)?  $default,){
final _that = this;
switch (_that) {
case _FileTree() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String path,  IList<FileTree> directories,  IList<BrowserSample> samples)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileTree() when $default != null:
return $default(_that.name,_that.path,_that.directories,_that.samples);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String path,  IList<FileTree> directories,  IList<BrowserSample> samples)  $default,) {final _that = this;
switch (_that) {
case _FileTree():
return $default(_that.name,_that.path,_that.directories,_that.samples);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String path,  IList<FileTree> directories,  IList<BrowserSample> samples)?  $default,) {final _that = this;
switch (_that) {
case _FileTree() when $default != null:
return $default(_that.name,_that.path,_that.directories,_that.samples);case _:
  return null;

}
}

}

/// @nodoc


class _FileTree implements FileTree {
  const _FileTree({required this.name, required this.path, this.directories = const IListConst<FileTree>([]), this.samples = const IListConst<BrowserSample>([])});
  

@override final  String name;
@override final  String path;
@override@JsonKey() final  IList<FileTree> directories;
@override@JsonKey() final  IList<BrowserSample> samples;

/// Create a copy of FileTree
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileTreeCopyWith<_FileTree> get copyWith => __$FileTreeCopyWithImpl<_FileTree>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileTree&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.directories, directories)&&const DeepCollectionEquality().equals(other.samples, samples));
}


@override
int get hashCode => Object.hash(runtimeType,name,path,const DeepCollectionEquality().hash(directories),const DeepCollectionEquality().hash(samples));

@override
String toString() {
  return 'FileTree(name: $name, path: $path, directories: $directories, samples: $samples)';
}


}

/// @nodoc
abstract mixin class _$FileTreeCopyWith<$Res> implements $FileTreeCopyWith<$Res> {
  factory _$FileTreeCopyWith(_FileTree value, $Res Function(_FileTree) _then) = __$FileTreeCopyWithImpl;
@override @useResult
$Res call({
 String name, String path, IList<FileTree> directories, IList<BrowserSample> samples
});




}
/// @nodoc
class __$FileTreeCopyWithImpl<$Res>
    implements _$FileTreeCopyWith<$Res> {
  __$FileTreeCopyWithImpl(this._self, this._then);

  final _FileTree _self;
  final $Res Function(_FileTree) _then;

/// Create a copy of FileTree
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = null,Object? directories = null,Object? samples = null,}) {
  return _then(_FileTree(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,directories: null == directories ? _self.directories : directories // ignore: cast_nullable_to_non_nullable
as IList<FileTree>,samples: null == samples ? _self.samples : samples // ignore: cast_nullable_to_non_nullable
as IList<BrowserSample>,
  ));
}


}

/// @nodoc
mixin _$BrowserPanelState {

 bool get isExpanded; bool get isLoadingDirectory; IMap<String, FileTree> get directories; ISet<String> get expandedDirectoryPaths; String? get selectedSamplePath;
/// Create a copy of BrowserPanelState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BrowserPanelStateCopyWith<BrowserPanelState> get copyWith => _$BrowserPanelStateCopyWithImpl<BrowserPanelState>(this as BrowserPanelState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BrowserPanelState&&(identical(other.isExpanded, isExpanded) || other.isExpanded == isExpanded)&&(identical(other.isLoadingDirectory, isLoadingDirectory) || other.isLoadingDirectory == isLoadingDirectory)&&(identical(other.directories, directories) || other.directories == directories)&&const DeepCollectionEquality().equals(other.expandedDirectoryPaths, expandedDirectoryPaths)&&(identical(other.selectedSamplePath, selectedSamplePath) || other.selectedSamplePath == selectedSamplePath));
}


@override
int get hashCode => Object.hash(runtimeType,isExpanded,isLoadingDirectory,directories,const DeepCollectionEquality().hash(expandedDirectoryPaths),selectedSamplePath);

@override
String toString() {
  return 'BrowserPanelState(isExpanded: $isExpanded, isLoadingDirectory: $isLoadingDirectory, directories: $directories, expandedDirectoryPaths: $expandedDirectoryPaths, selectedSamplePath: $selectedSamplePath)';
}


}

/// @nodoc
abstract mixin class $BrowserPanelStateCopyWith<$Res>  {
  factory $BrowserPanelStateCopyWith(BrowserPanelState value, $Res Function(BrowserPanelState) _then) = _$BrowserPanelStateCopyWithImpl;
@useResult
$Res call({
 bool isExpanded, bool isLoadingDirectory, IMap<String, FileTree> directories, ISet<String> expandedDirectoryPaths, String? selectedSamplePath
});




}
/// @nodoc
class _$BrowserPanelStateCopyWithImpl<$Res>
    implements $BrowserPanelStateCopyWith<$Res> {
  _$BrowserPanelStateCopyWithImpl(this._self, this._then);

  final BrowserPanelState _self;
  final $Res Function(BrowserPanelState) _then;

/// Create a copy of BrowserPanelState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isExpanded = null,Object? isLoadingDirectory = null,Object? directories = null,Object? expandedDirectoryPaths = null,Object? selectedSamplePath = freezed,}) {
  return _then(_self.copyWith(
isExpanded: null == isExpanded ? _self.isExpanded : isExpanded // ignore: cast_nullable_to_non_nullable
as bool,isLoadingDirectory: null == isLoadingDirectory ? _self.isLoadingDirectory : isLoadingDirectory // ignore: cast_nullable_to_non_nullable
as bool,directories: null == directories ? _self.directories : directories // ignore: cast_nullable_to_non_nullable
as IMap<String, FileTree>,expandedDirectoryPaths: null == expandedDirectoryPaths ? _self.expandedDirectoryPaths : expandedDirectoryPaths // ignore: cast_nullable_to_non_nullable
as ISet<String>,selectedSamplePath: freezed == selectedSamplePath ? _self.selectedSamplePath : selectedSamplePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BrowserPanelState].
extension BrowserPanelStatePatterns on BrowserPanelState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BrowserPanelState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BrowserPanelState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BrowserPanelState value)  $default,){
final _that = this;
switch (_that) {
case _BrowserPanelState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BrowserPanelState value)?  $default,){
final _that = this;
switch (_that) {
case _BrowserPanelState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isExpanded,  bool isLoadingDirectory,  IMap<String, FileTree> directories,  ISet<String> expandedDirectoryPaths,  String? selectedSamplePath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BrowserPanelState() when $default != null:
return $default(_that.isExpanded,_that.isLoadingDirectory,_that.directories,_that.expandedDirectoryPaths,_that.selectedSamplePath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isExpanded,  bool isLoadingDirectory,  IMap<String, FileTree> directories,  ISet<String> expandedDirectoryPaths,  String? selectedSamplePath)  $default,) {final _that = this;
switch (_that) {
case _BrowserPanelState():
return $default(_that.isExpanded,_that.isLoadingDirectory,_that.directories,_that.expandedDirectoryPaths,_that.selectedSamplePath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isExpanded,  bool isLoadingDirectory,  IMap<String, FileTree> directories,  ISet<String> expandedDirectoryPaths,  String? selectedSamplePath)?  $default,) {final _that = this;
switch (_that) {
case _BrowserPanelState() when $default != null:
return $default(_that.isExpanded,_that.isLoadingDirectory,_that.directories,_that.expandedDirectoryPaths,_that.selectedSamplePath);case _:
  return null;

}
}

}

/// @nodoc


class _BrowserPanelState implements BrowserPanelState {
  const _BrowserPanelState({this.isExpanded = false, this.isLoadingDirectory = false, this.directories = const IMapConst<String, FileTree>({}), this.expandedDirectoryPaths = const ISetConst<String>({}), this.selectedSamplePath});
  

@override@JsonKey() final  bool isExpanded;
@override@JsonKey() final  bool isLoadingDirectory;
@override@JsonKey() final  IMap<String, FileTree> directories;
@override@JsonKey() final  ISet<String> expandedDirectoryPaths;
@override final  String? selectedSamplePath;

/// Create a copy of BrowserPanelState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BrowserPanelStateCopyWith<_BrowserPanelState> get copyWith => __$BrowserPanelStateCopyWithImpl<_BrowserPanelState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BrowserPanelState&&(identical(other.isExpanded, isExpanded) || other.isExpanded == isExpanded)&&(identical(other.isLoadingDirectory, isLoadingDirectory) || other.isLoadingDirectory == isLoadingDirectory)&&(identical(other.directories, directories) || other.directories == directories)&&const DeepCollectionEquality().equals(other.expandedDirectoryPaths, expandedDirectoryPaths)&&(identical(other.selectedSamplePath, selectedSamplePath) || other.selectedSamplePath == selectedSamplePath));
}


@override
int get hashCode => Object.hash(runtimeType,isExpanded,isLoadingDirectory,directories,const DeepCollectionEquality().hash(expandedDirectoryPaths),selectedSamplePath);

@override
String toString() {
  return 'BrowserPanelState(isExpanded: $isExpanded, isLoadingDirectory: $isLoadingDirectory, directories: $directories, expandedDirectoryPaths: $expandedDirectoryPaths, selectedSamplePath: $selectedSamplePath)';
}


}

/// @nodoc
abstract mixin class _$BrowserPanelStateCopyWith<$Res> implements $BrowserPanelStateCopyWith<$Res> {
  factory _$BrowserPanelStateCopyWith(_BrowserPanelState value, $Res Function(_BrowserPanelState) _then) = __$BrowserPanelStateCopyWithImpl;
@override @useResult
$Res call({
 bool isExpanded, bool isLoadingDirectory, IMap<String, FileTree> directories, ISet<String> expandedDirectoryPaths, String? selectedSamplePath
});




}
/// @nodoc
class __$BrowserPanelStateCopyWithImpl<$Res>
    implements _$BrowserPanelStateCopyWith<$Res> {
  __$BrowserPanelStateCopyWithImpl(this._self, this._then);

  final _BrowserPanelState _self;
  final $Res Function(_BrowserPanelState) _then;

/// Create a copy of BrowserPanelState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isExpanded = null,Object? isLoadingDirectory = null,Object? directories = null,Object? expandedDirectoryPaths = null,Object? selectedSamplePath = freezed,}) {
  return _then(_BrowserPanelState(
isExpanded: null == isExpanded ? _self.isExpanded : isExpanded // ignore: cast_nullable_to_non_nullable
as bool,isLoadingDirectory: null == isLoadingDirectory ? _self.isLoadingDirectory : isLoadingDirectory // ignore: cast_nullable_to_non_nullable
as bool,directories: null == directories ? _self.directories : directories // ignore: cast_nullable_to_non_nullable
as IMap<String, FileTree>,expandedDirectoryPaths: null == expandedDirectoryPaths ? _self.expandedDirectoryPaths : expandedDirectoryPaths // ignore: cast_nullable_to_non_nullable
as ISet<String>,selectedSamplePath: freezed == selectedSamplePath ? _self.selectedSamplePath : selectedSamplePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
