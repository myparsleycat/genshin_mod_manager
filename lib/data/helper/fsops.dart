import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:genshin_mod_manager/data/helper/path_op_string.dart';
import 'package:genshin_mod_manager/domain/entity/mod.dart';
import 'package:genshin_mod_manager/domain/entity/mod_category.dart';

/// Returns a [Mod] list from the given [category].
Future<List<Mod>> getMods(final ModCategory category) async {
  final root = category.path;
  final res =
      Directory(root).listSync().whereType<Directory>().map((final event) {
    final path = event.path;
    return Mod(
      path: path,
      displayName: path.pEnabledForm.pBasename,
      isEnabled: path.pIsEnabled,
      category: category,
    );
  }).toList();
  return UnmodifiableListView(res);
}

/// Returns active ini paths from the given [paths].
List<String> getActiveIniPaths(final List<String> paths) =>
    paths.where((final path) {
      final extension = path.pExtension;
      if (!extension.pEquals('.ini')) {
        return false;
      }
      return path.pBasename.pIsEnabled;
    }).toList();

/// Returns a String path list under the given [path].
List<String> getUnder<T extends FileSystemEntity>(
  final String path,
) {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    return [];
  }
  final res =
      dir.listSync().whereType<T>().map((final event) => event.path).toList();
  return res;
}

/// Returns a String path list under the given [path], synchronously.
List<String> getUnderSync<T extends FileSystemEntity>(
  final String path,
) {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    return [];
  }
  final res =
      dir.listSync().whereType<T>().map((final event) => event.path).toList();
  return res;
}

const _previewExtensions = [
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
];

/// In the [paths] list, find a file path that has a [name],
/// ignoring extensions.
String? findPreviewFileInString(
  final List<String> paths, {
  final String name = 'preview',
}) {
  for (final element in paths) {
    final filename = element.pBNameWoExt;
    if (!filename.pEquals(name)) {
      continue;
    }
    final ext = element.pExtension;
    for (final previewExt in _previewExtensions) {
      if (ext.pEquals(previewExt)) {
        return element;
      }
    }
  }
  return null;
}

/// Runs a [program] by default method.
void runProgram(final File program) {
  final pwd = program.parent.path;
  final pName = program.path.pBasename;
  unawaited(
    Process.run('start', ['/b', '/d', pwd, '', pName], runInShell: true),
  );
}

/// Opens a folder at [path].
void openFolder(final String path) {
  unawaited(Process.start('explorer', [path], runInShell: true));
}
