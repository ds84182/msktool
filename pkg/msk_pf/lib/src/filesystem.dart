library msk.pf.src.filesystem;

import 'dart:async';
import 'dart:convert';
import 'package:file/file.dart';
import 'package:file/src/common.dart';
import 'package:path/path.dart' as p;
import 'context.dart';

class PFFileSystem extends FileSystem {
  final PFContext context;

  PFFileSystem(this.context);

  Directory directory(dynamic inPath) {
    final split = path.split(path.canonicalize(getPath(inPath)));

    final level = split.length > 4 ? PFFSLevel.invalid : PFFSLevel.list[split.length-1];

    return new PFFSDirectory._(
      fileSystem: this,
      path: path.joinAll(split),
      level: level
    );
  }

  @override
  final p.Context path = new p.Context(style: p.Style.posix, current: "/");

  @override
  Directory get currentDirectory => directory("/");

  @override
  set currentDirectory(_) => throw "Not supported";

  @override
  File file(path) {
    // TODO: implement file
    throw UnimplementedError();
  }

  @override
  Future<bool> identical(String path1, String path2) =>
      new Future.value(identicalSync(path1, path2));

  @override
  bool identicalSync(String path1, String path2) {
    return path.equals(path1, path2);
  }

  @override
  bool get isWatchSupported => false;

  @override
  Link link(path) {
    throw "Link not supported";
  }

  @override
  Future<FileStat> stat(String path) {
    throw "Stat not supported";
  }

  @override
  FileStat statSync(String path) {
    throw "Stat not supported";
  }

  @override
  Directory get systemTempDirectory => null;

  @override
  Future<FileSystemEntityType> type(String path, {bool followLinks: true}) =>
      new Future.value(typeSync(path));

  @override
  FileSystemEntityType typeSync(String inPath, {bool followLinks: true}) {
    final split = path.split(path.canonicalize(getPath(inPath)));
    final level = split.length > 4 ? PFFSLevel.invalid : PFFSLevel.list[split.length-1];
    return level.isFile ? FileSystemEntityType.file : FileSystemEntityType.directory;
  }
}

class PFFSLevel {
  final int index;
  final String name;
  final bool isFile;

  const PFFSLevel(this.index, this.name, {this.isFile: false});

  PFFSLevel get next =>
      this == invalid ? invalid : list[index + 1];

  static const root = const PFFSLevel(0, "root");
  static const package = const PFFSLevel(1, "package");
  static const type = const PFFSLevel(2, "type");
  static const entry = const PFFSLevel(3, "entry", isFile: true);
  static const invalid = const PFFSLevel(4, "invalid");

  static const list = const [
    root, package, type, entry, invalid
  ];
}

FileSystemException _rofs(String path) =>
    new FileSystemException("Read-only file system", path, new OSError("Read only filesystem", ErrorCodes.EROFS));

abstract class PFFSEntity<T extends FileSystemEntity> extends FileSystemEntity {
  @override
  PFFileSystem get fileSystem;

  @override
  String get path;

  PFFSLevel get level;

  @override
  T get absolute => this as T;

  @override
  String get basename => fileSystem.path.basename(path);

  @override
  Future<FileSystemEntity> delete({bool recursive: false}) {
    throw _rofs(path);
  }

  @override
  void deleteSync({bool recursive: false}) {
    throw _rofs(path);
  }

  @override
  String get dirname => fileSystem.path.dirname(path);

  @override
  Future<bool> exists();

  @override
  bool existsSync();

  @override
  bool get isAbsolute => true;

  @override
  Directory get parent => fileSystem.directory(fileSystem.path.join(path, '..'));

  @override
  Future<T> rename(String newPath) {
    throw _rofs(path);
  }

  @override
  T renameSync(String newPath) {
    throw _rofs(path);
  }

  @override
  Future<String> resolveSymbolicLinks() =>
      new Future.value(path);

  @override
  String resolveSymbolicLinksSync() => path;

  @override
  Future<FileStat> stat();

  @override
  FileStat statSync();

  @override
  Uri get uri => new Uri(scheme: "pf", path: path);

  @override
  Stream<FileSystemEvent> watch({int events: FileSystemEvent.all, bool recursive: false}) {
    throw invalidArgument(path);
  }
}

class PFFSDirectory extends PFFSEntity<PFFSDirectory> with DirectoryAddOnsMixin implements Directory {
  @override
  final PFFileSystem fileSystem;

  @override
  final String path;

  @override
  final PFFSLevel level;

  PFFSDirectory._({
    this.fileSystem,
    this.path,
    this.level
  });

  @override
  PFFSDirectory get absolute => this;

  @override
  Future<Directory> create({bool recursive: false}) {
    throw _rofs(path);
  }

  @override
  void createSync({bool recursive: false}) {
    throw _rofs(path);
  }

  @override
  Future<Directory> createTemp([String prefix]) {
    throw _rofs(path);
  }

  @override
  Directory createTempSync([String prefix]) {
    throw _rofs(path);
  }

  @override
  Future<bool> exists() => new Future.value(existsSync());

  @override
  bool existsSync() {
    switch (level) {
      case PFFSLevel.root:
        return true;
      case PFFSLevel.package:
        return fileSystem.context.findPackage(basename) != null;
      case PFFSLevel.invalid:
        return false;
    }
    print("Unimplemented level PFFSLevel.${level.name} for existsSync");
    return false;
  }

  @override
  bool get isAbsolute => true;

  @override
  Stream<FileSystemEntity> list({bool recursive: false, bool followLinks: true}) {
    return new Stream.fromIterable(listSync(recursive: recursive, followLinks: followLinks));
  }

  @override
  List<FileSystemEntity> listSync({bool recursive: false, bool followLinks: true}) {
    if (level == PFFSLevel.invalid || level.isFile) throw notADirectory(path);

    if (!existsSync()) throw noSuchFileOrDirectory(path);

    Iterable<FileSystemEntity> result;

    switch (level) {
      case PFFSLevel.root:
        result = fileSystem.context.header.packageHeaders.map((pkgHeader) {
          return childDirectory(pkgHeader.packageName);
        });
        break;
      case PFFSLevel.package: {
        final package = fileSystem.context.findPackage(basename);
        result = package.package.types.map((type) {
          return childDirectory(type.name);
        });
        break;
      }
      case PFFSLevel.type: {
        final package = fileSystem.context.findPackage(fileSystem.path.split(path)[2]);
        final type = package.package.types
            .firstWhere((typ) => typ.name != basename);
        final offset = package.package.types
            .takeWhile((typ) => typ != type)
            .fold(0, (a, typ) => a + typ.count);
        result = package.package.entries
            .skip(offset)
            .take(type.count)
            .map((entry) {
              return childFile(entry.name);
            });
        break;
      }
    }

    if (recursive) {
      result = result.expand((fse) {
        if (fse is Directory) {
          return fse.listSync(recursive: true);
        } else {
          return [fse];
        }
      });
    }

    return result.toList();
  }

  @override
  Future<FileStat> stat() {
    return new Future.value(statSync());
  }

  @override
  FileStat statSync() {
    throw "NYI: Stat";
  }
}

class PFFSFile extends PFFSEntity<PFFSFile> implements File {
  @override
  final PFFileSystem fileSystem;

  @override
  final String path;

  @override
  final PFFSLevel level;

  PFFSFile._({
    this.fileSystem,
    this.path,
    this.level
  });

  @override
  Future<File> copy(String newPath) {
    throw _rofs(path);
  }

  @override
  File copySync(String newPath) {
    throw _rofs(path);
  }

  @override
  Future<File> create({bool recursive: false}) {
    throw _rofs(path);
  }

  @override
  void createSync({bool recursive: false}) {
    throw _rofs(path);
  }

  @override
  Future<bool> exists() {
    // TODO: implement exists
    throw UnimplementedError();
  }

  @override
  bool existsSync() {
    // TODO: implement existsSync
    throw UnimplementedError();
  }

  @override
  Future<DateTime> lastAccessed() async {
    return new DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  DateTime lastAccessedSync() {
    return new DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Future<DateTime> lastModified() async {
    return new DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  DateTime lastModifiedSync() {
    return new DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Future<int> length() {
    // TODO: implement length
    throw UnimplementedError();
  }

  @override
  int lengthSync() {
    // TODO: implement lengthSync
    throw UnimplementedError();
  }

  @override
  Future<RandomAccessFile> open({FileMode mode: FileMode.read}) {
    // TODO: implement open
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead([int start, int end]) {
    // TODO: implement openRead
    throw UnimplementedError();
  }

  @override
  RandomAccessFile openSync({FileMode mode: FileMode.read}) {
    // TODO: implement openSync
    throw UnimplementedError();
  }

  @override
  IOSink openWrite({FileMode mode: FileMode.write, Encoding encoding: utf8}) {
    // TODO: implement openWrite
    throw UnimplementedError();
  }

  @override
  Future<List<int>> readAsBytes() {
    // TODO: implement readAsBytes
    throw UnimplementedError();
  }

  @override
  List<int> readAsBytesSync() {
    // TODO: implement readAsBytesSync
    throw UnimplementedError();
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding: utf8}) {
    // TODO: implement readAsLines
    throw UnimplementedError();
  }

  @override
  List<String> readAsLinesSync({Encoding encoding: utf8}) {
    // TODO: implement readAsLinesSync
    throw UnimplementedError();
  }

  @override
  Future<String> readAsString({Encoding encoding: utf8}) {
    // TODO: implement readAsString
    throw UnimplementedError();
  }

  @override
  String readAsStringSync({Encoding encoding: utf8}) {
    // TODO: implement readAsStringSync
    throw UnimplementedError();
  }

  @override
  Future setLastAccessed(DateTime time) {
    throw _rofs(path);
  }

  @override
  void setLastAccessedSync(DateTime time) {
    throw _rofs(path);
  }

  @override
  Future setLastModified(DateTime time) {
    throw _rofs(path);
  }

  @override
  void setLastModifiedSync(DateTime time) {
    throw _rofs(path);
  }

  @override
  Future<FileStat> stat() {
    // TODO: implement stat
    throw UnimplementedError();
  }

  @override
  FileStat statSync() {
    // TODO: implement statSync
    throw UnimplementedError();
  }

  @override
  Future<File> writeAsBytes(List<int> bytes, {FileMode mode: FileMode.write, bool flush: false}) {
    throw _rofs(path);
  }

  @override
  void writeAsBytesSync(List<int> bytes, {FileMode mode: FileMode.write, bool flush: false}) {
    throw _rofs(path);
  }

  @override
  Future<File> writeAsString(String contents, {FileMode mode: FileMode.write, Encoding encoding: utf8, bool flush: false}) {
    throw _rofs(path);
  }

  @override
  void writeAsStringSync(String contents, {FileMode mode: FileMode.write, Encoding encoding: utf8, bool flush: false}) {
    throw _rofs(path);
  }
}
