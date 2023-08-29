import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:genshin_mod_manager/base/directory_watch_widget.dart';
import 'package:genshin_mod_manager/extension/pathops.dart';
import 'package:genshin_mod_manager/io/fsops.dart';
import 'package:genshin_mod_manager/provider/app_state.dart';
import 'package:genshin_mod_manager/widget/editor_text.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class FolderCard extends DirectoryWatchWidget {
  FolderCard({required super.dirPath}) : super(key: ValueKey(dirPath));

  @override
  DWState<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends DWState<FolderCard> {
  static const shaderFixes = PathString('ShaderFixes');
  static final Logger logger = Logger();

  @override
  Widget build(BuildContext context) {
    PathString basename = widget.dir.basename;
    final isDisabled = basename.startsWith('DISABLED ');
    String displayName = basename.asString;
    final color = isDisabled
        ? Colors.red.lightest.withOpacity(0.5)
        : Colors.green.lightest;
    if (isDisabled) {
      displayName = displayName.substring(9);
    }

    return GestureDetector(
      onTap: () {
        if (isDisabled) {
          toggleEnable(context, displayName);
        } else {
          toggleDisable(context, displayName);
        }
      },
      child: Card(
        backgroundColor: color,
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            buildFolderHeader(context, displayName),
            const SizedBox(height: 4),
            buildFolderContent(context, displayName),
          ],
        ),
      ),
    );
  }

  Widget buildFolderHeader(BuildContext context, String displayName) {
    return Row(
      children: [
        Expanded(
          child: Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
        ),
        const SizedBox(width: 4),
        Button(
          child: const Icon(FluentIcons.folder_open),
          onPressed: () => openFolder(widget.dir),
        ),
      ],
    );
  }

  Widget buildFolderContent(BuildContext context, String displayName) {
    return Expanded(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildDesc(context, constraints),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Divider(direction: Axis.vertical),
              ),
              buildIni(),
            ],
          );
        },
      ),
    );
  }

  Widget buildDesc(BuildContext context, BoxConstraints constraints) {
    final previewFile = findPreviewFile(widget.dir);
    if (previewFile == null) {
      return const Expanded(child: Center(child: Icon(FluentIcons.unknown)));
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth - 150,
      ),
      child: Image.file(
        previewFile,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  Widget buildIni() {
    final alliniFile = allFilesToWidget(getActiveiniFiles(widget.dir));
    return Expanded(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 80,
        ),
        child: alliniFile.isNotEmpty
            ? Card(
                backgroundColor: Colors.white.withOpacity(0.4),
                padding: const EdgeInsets.all(4),
                child: ListView(
                  children: alliniFile,
                ),
              )
            : const Center(
                child: Text('No ini files found'),
              ),
      ),
    );
  }

  void toggleEnable(BuildContext context, String displayName) {
    final List<File> shaderFilenames = [];
    final modShaderDir = widget.dirPath.join(shaderFixes).toDirectory;
    try {
      shaderFilenames.addAll(getFilesUnder(modShaderDir));
    } on PathNotFoundException catch (e) {
      logger.i(e);
    }

    final PathString renameTarget =
        widget.dir.parent.join(PathString(displayName));
    if (renameTarget.toDirectory.existsSync()) {
      showDirectoryExists(context, renameTarget);
      return;
    }
    final tgt =
        context.read<AppState>().targetDir.join(shaderFixes).toDirectory;
    try {
      copyShaders(tgt, shaderFilenames);
    } on FileSystemException catch (e) {
      logger.w(e);
      errorDialog(context, '${e.path} already exists!');
      return;
    }
    try {
      widget.dir.renameSyncPath(renameTarget);
    } on PathAccessException {
      errorDialog(
          context,
          'Failed to rename folder.'
          ' Check if the ShaderFixes folder is open in explorer,'
          ' and close it if it is.');
      deleteShaders(tgt, shaderFilenames);
    }
  }

  void toggleDisable(BuildContext context, String displayName) {
    final List<File> shaderFilenames = [];
    final modShaderDir = widget.dirPath.join(shaderFixes).toDirectory;
    try {
      shaderFilenames.addAll(getFilesUnder(modShaderDir));
    } on PathNotFoundException catch (e) {
      logger.i(e);
    }

    final PathString renameTarget =
        widget.dir.parent.join(PathString('DISABLED $displayName'));
    if (renameTarget.toDirectory.existsSync()) {
      showDirectoryExists(context, renameTarget);
      return;
    }
    final tgt =
        context.read<AppState>().targetDir.join(shaderFixes).toDirectory;
    try {
      deleteShaders(tgt, shaderFilenames);
    } catch (e) {
      logger.w(e);
      errorDialog(context, 'Failed to delete files in ShaderFixes');
      return;
    }
    try {
      widget.dir.renameSyncPath(renameTarget);
    } on PathAccessException {
      errorDialog(
          context,
          'Failed to rename folder.'
          ' Check if the ShaderFixes folder is open in explorer,'
          ' and close it if it is.');
      copyShaders(tgt, shaderFilenames);
    }
  }

  void copyShaders(Directory targetDir, List<File> shaderFiles) {
    // check for existence first
    final targetDirFileList = getFilesUnder(targetDir);
    for (final em in shaderFiles) {
      final modFilename = em.basename;
      for (final et in targetDirFileList) {
        final tgtFilename = et.basename;
        if (tgtFilename == modFilename) {
          throw FileSystemException(
            'Target directory is not empty',
            tgtFilename.asString,
          );
        }
      }
    }
    for (final em in shaderFiles) {
      final modFilename = em.basename;
      final moveName = targetDir.join(modFilename);
      em.copySyncPath(moveName);
    }
  }

  void deleteShaders(Directory targetDir, List<File> shaderFilenames) {
    final targetDirFileList = getFilesUnder(targetDir);
    for (final em in shaderFilenames) {
      final modFilename = em.basename;
      for (final et in targetDirFileList) {
        final tgtFilename = et.basename;
        if (tgtFilename == modFilename) {
          et.deleteSync();
        }
      }
    }
  }

  void showDirectoryExists(BuildContext context, PathString renameTarget) {
    renameTarget = renameTarget.basename;
    errorDialog(context, '$renameTarget already exists!');
  }

  void errorDialog(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Error'),
        content: Text(text),
        actions: [
          FilledButton(
            child: const Text('Ok'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldUpdate(FileSystemEvent event) {
    return true;
  }

  @override
  void updateFolder() {
    setState(() {});
  }
}

List<Widget> allFilesToWidget(List<File> allFiles) {
  final List<Widget> alliniFile = [];
  for (var i = 0; i < allFiles.length; i++) {
    final cur = allFiles[i];
    alliniFile.add(buildIniHeader(cur));
    late String lastSection;
    bool metSection = false;
    cur
        .readAsLinesSync(encoding: const Utf8Codec(allowMalformed: true))
        .forEach((line) {
      if (line.startsWith('[')) {
        metSection = false;
      }
      final regExp = RegExp(r'\[Key.*?\]');
      final match = regExp.firstMatch(line)?.group(0)!;
      if (match != null) {
        alliniFile.add(Text(match));
        lastSection = match;
        metSection = true;
      }
      final lineLower = line.toLowerCase();
      if (lineLower.startsWith('key')) {
        alliniFile.add(buildIniFieldEditor('key:', lastSection, line, cur));
      } else if (lineLower.startsWith('back')) {
        alliniFile.add(buildIniFieldEditor('back:', lastSection, line, cur));
      } else if (line.startsWith('\$') && metSection) {
        final cycles = ','.allMatches(line.split(';').first).length + 1;
        alliniFile.add(Text('Cycles: $cycles'));
      }
    });
  }
  return alliniFile;
}

Widget buildIniHeader(File iniFile) {
  final iniName = iniFile.basename;
  return Row(
    children: [
      Expanded(
        child: Tooltip(
          message: iniName.asString,
          child: Text(
            iniName.asString,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      Button(
        child: const Icon(FluentIcons.document_management),
        onPressed: () => runProgram(iniFile),
      ),
    ],
  );
}

Widget buildIniFieldEditor(
    String data, String section, String line, File file) {
  return Row(
    children: [
      Text(data),
      Expanded(
        child: EditorText(
          section: section,
          line: line,
          file: file,
        ),
      ),
    ],
  );
}
