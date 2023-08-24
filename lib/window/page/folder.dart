import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:genshin_mod_manager/base/directory_watch_widget.dart';
import 'package:genshin_mod_manager/io/fsops.dart';
import 'package:genshin_mod_manager/third_party/min_extent_delegate.dart';
import 'package:genshin_mod_manager/window/widget/editor_text.dart';
import 'package:genshin_mod_manager/window/widget/folder_card.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

class FolderPage extends DirectoryWatchWidget {
  const FolderPage({
    super.key,
    required super.dirPath,
  });

  @override
  DWState<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends DWState<FolderPage> {
  static final Logger logger = Logger();
  late List<Directory> allChildrenFolder;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(p.basename(widget.dir.path)),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.folder_open),
              onPressed: () {
                openFolder(widget.dir);
              },
            ),
          ],
        ),
      ),
      content: GridView(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMinCrossAxisExtent(
          minCrossAxisExtent: 350,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 420,
        ),
        children: allChildrenFolder.map((e) => FolderCard(e)).toList(),
      ),
    );
  }

  @override
  void onUpdate() {
    final newDir = widget.dir;
    updateFolder(newDir);
    subscription = newDir.watch().listen((event) {
      if (event is FileSystemModifyEvent && event.contentChanged) {
        logger.d('Ignoring content change event: $event');
        return;
      }
      setState(() => updateFolder(newDir));
    });
  }

  void updateFolder(Directory dir) {
    allChildrenFolder = getAllChildrenFolder(dir)
      ..sort(
        (a, b) {
          var aName = p.basename(a.path);
          var bName = p.basename(b.path);
          aName = aName.startsWith('DISABLED ') ? aName.substring(9) : aName;
          bName = bName.startsWith('DISABLED ') ? bName.substring(9) : bName;
          return aName.toLowerCase().compareTo(bName.toLowerCase());
        },
      );
  }
}

class IniList extends StatefulWidget {
  final Directory folder;

  const IniList(
    this.folder, {
    super.key,
  });

  @override
  State<IniList> createState() => _IniListState();
}

class _IniListState extends State<IniList> {
  late StreamSubscription<FileSystemEvent> watcher;

  @override
  void initState() {
    super.initState();
    watcher = widget.folder.watch().listen((event) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    watcher.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alliniFile = allFilesToWidget(getActiveiniFiles(widget.folder));
    return Flexible(
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
    );
  }
}

List<Widget> allFilesToWidget(List<File> allFiles) {
  List<Widget> alliniFile = [];
  for (var i = 0; i < allFiles.length; i++) {
    final folderName = p.basename(allFiles[i].path);
    alliniFile.add(Row(
      children: [
        Expanded(
          child: Tooltip(
            message: folderName,
            child: Text(
              folderName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Button(
          child: const Icon(FluentIcons.document_management),
          onPressed: () => runProgram(allFiles[i]),
        ),
      ],
    ));
    late String lastSection;
    bool metSection = false;
    allFiles[i].readAsLinesSync().forEach((e) {
      if (e.startsWith('[')) {
        metSection = false;
      }
      final regExp = RegExp(r'\[Key.*?\]');
      final match = regExp.firstMatch(e)?.group(0)!;
      if (match != null) {
        alliniFile.add(Text(match));
        lastSection = match;
        metSection = true;
      }
      if (e.toLowerCase().startsWith('key')) {
        alliniFile.add(Row(
          children: [
            const Text(
              'key:',
            ),
            Expanded(
              child: EditorText(
                section: lastSection,
                line: e,
                file: allFiles[i],
              ),
            )
          ],
        ));
      } else if (e.toLowerCase().startsWith('back')) {
        alliniFile.add(Row(
          children: [
            const Text(
              'back:',
            ),
            Expanded(
              child: EditorText(
                section: lastSection,
                line: e,
                file: allFiles[i],
              ),
            )
          ],
        ));
      } else if (e.startsWith('\$') && metSection) {
        final cycles = ','.allMatches(e.split(';').first).length + 1;
        alliniFile.add(Text('Cycles: $cycles'));
      }
    });
  }
  return alliniFile;
}
