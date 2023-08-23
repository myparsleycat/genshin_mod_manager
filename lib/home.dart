import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'fsops.dart';
import 'page/folder.dart';
import 'page/setting.dart';

class HomeWindow extends StatefulWidget {
  static Logger logger = Logger();
  final Directory dir;

  const HomeWindow(this.dir, {super.key});

  @override
  State<HomeWindow> createState() => _HomeWindowState();
}

class _HomeWindowState extends State<HomeWindow> with WindowListener {
  late StreamSubscription<List<Directory>> subscription;
  late List<NavigationPaneItem> subFolders;

  int? selected;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    onDirChange(widget.dir);
  }

  @override
  void didUpdateWidget(covariant HomeWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDir = oldWidget.dir;
    final newDir = widget.dir;
    if (oldDir == newDir) return;
    HomeWindow.logger.i('Directory changed from $oldDir to $newDir');
    subscription.cancel();
    onDirChange(newDir);
  }

  @override
  void dispose() {
    subscription.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      appBar: buildNavigationAppBar(),
      pane: buildNavigationPane(context),
    );
  }

  NavigationAppBar buildNavigationAppBar() {
    return const NavigationAppBar(
      title: DragToMoveArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Genshin Mod Manager'),
        ),
      ),
      automaticallyImplyLeading: false,
      actions: WindowButtons(),
    );
  }

  NavigationPane buildNavigationPane(BuildContext context) {
    final List<AutoSuggestBoxItem<Key>> autoSuggestBoxItems = subFolders
        .map((e) => AutoSuggestBoxItem(
              value: e.key,
              label: p.basename((e as FolderPaneItem).dir.path),
            ))
        .toList();
    return NavigationPane(
      selected: selected,
      onChanged: (i) {
        final length = subFolders.length;
        HomeWindow.logger.i('Selected $i. Length: $length');
        if (i == length || i == length + 1) {
          HomeWindow.logger.i('Selected program runners. Ignoring change.');
          return;
        }
        setState(() => selected = i);
      },
      displayMode: PaneDisplayMode.auto,
      size: const NavigationPaneSize(openWidth: 300),
      autoSuggestBox: AutoSuggestBox(
        items: autoSuggestBoxItems,
        trailingIcon: const Icon(FluentIcons.search),
        onSelected: (item) {
          setState(() {
            selected = subFolders.indexWhere((e) => e.key == item.value);
          });
        },
      ),
      autoSuggestBoxReplacement: const Icon(FluentIcons.search),
      items: subFolders,
      footerItems: [
        PaneItemSeparator(),
        PaneItem(
          icon: const Icon(FluentIcons.user_window),
          title: const Text('3d migoto'),
          body: Center(child: Image.asset('images/app_icon.ico')),
          onTap: () {
            final tDir = context.read<AppState>().targetDir;
            final path = p.join(tDir.path, '3DMigoto Loader.exe');
            final file = File(path);
            runProgram(file);
            HomeWindow.logger.i('Ran 3d migoto $file');
          },
        ),
        PaneItem(
          icon: const Icon(FluentIcons.user_window),
          title: const Text('Launcher'),
          body: Center(child: Image.asset('images/app_icon.ico')),
          onTap: () {
            final launcher = context.read<AppState>().launcherFile;
            runProgram(launcher);
            HomeWindow.logger.i('Ran launcher $launcher');
          },
        ),
        PaneItem(
          icon: const Icon(FluentIcons.settings),
          title: const Text('Settings'),
          body: const SettingPage(),
        ),
      ],
    );
  }

  void onDirChange(Directory newDir) {
    updateFolder(newDir);
    subscription = newDir
        .watch()
        .map((dir) => getAllChildrenFolder(newDir))
        .listen((event) => setState(() => updateFolder(newDir)));
  }

  void updateFolder(Directory dir) {
    subFolders = [];
    final List<Directory> allFolder;
    try {
      allFolder = getAllChildrenFolder(dir);
    } on PathNotFoundException {
      HomeWindow.logger.e('Path not found: $dir');
      return;
    }
    for (var element in allFolder) {
      subFolders.add(FolderPaneItem(dir: element));
    }
  }
}

class FolderPaneItem extends PaneItem {
  Directory dir;

  FolderPaneItem({
    required this.dir,
  }) : super(
          title: Text(p.basename(dir.path)),
          icon: Image.asset('images/app_icon.ico'),
          body: FolderPage(dir: dir),
          key: ValueKey(dir.path),
        );
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 138,
      height: 50,
      child: WindowCaption(),
    );
  }
}
