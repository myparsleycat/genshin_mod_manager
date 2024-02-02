import 'dart:io';

import 'package:path/path.dart' as p;

extension PathFSE on FileSystemEntity {
  PathW get pathString => PathW(path);

  PathW get basename => pathString.basename;

  PathW get basenameWithoutExtension =>
      pathString.basenameWithoutExtension;

  PathW get extension => pathString.extension;

  PathW join(PathW str) => pathString.join(str);
}

extension PathF on File {
  File copySyncPath(PathW dest) => copySync(dest.asString);
}

extension PathD on Directory {
  Directory renameSyncPath(PathW dest) => renameSync(dest.asString);
}

class PathW {
  final String _path;

  String get asString => _path;

  const PathW(this._path);

  Directory get toDirectory => Directory(asString);

  File get toFile => File(asString);

  PathW get dirname => PathW(p.dirname(asString));

  PathW get basename => PathW(p.basename(asString));

  PathW get basenameWithoutExtension =>
      PathW(p.basenameWithoutExtension(asString));

  PathW get extension => PathW(p.extension(asString));

  bool get isDirectorySync => FileSystemEntity.isDirectorySync(asString);

  bool get isEnabled => !startsWith('DISABLED');

  PathW get enabledForm {
    if (!isEnabled) return PathW(asString.substring(8).trimLeft());
    return this;
  }

  PathW get disabledForm {
    if (isEnabled) return PathW('DISABLED ${asString.trimLeft()}');
    return this;
  }

  PathW join(PathW str) => PathW(p.join(asString, str.asString));

  bool startsWith(String s) {
    return asString.toLowerCase().startsWith(s.toLowerCase());
  }

  @override
  String toString() => asString;

  @override
  bool operator ==(Object other) {
    if (other is! PathW) return false;
    return p.equals(asString, other.asString);
  }

  @override
  int get hashCode => p.canonicalize(asString).hashCode;
}
