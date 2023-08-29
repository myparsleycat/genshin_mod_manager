import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:genshin_mod_manager/provider/app_state.dart';
import 'package:genshin_mod_manager/window/home.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

const _minWindowSize = Size(600, 600);

void main() async {
  await initialize();
  runApp(const MyApp());
}

Future<void> initialize() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setMinimumSize(_minWindowSize);
  });
}

class MyApp extends StatelessWidget {
  static const resourceDir = 'Resources';
  static const modDir = 'Mods';
  static const sharedPreferencesAwaitTime = Duration(seconds: 5);
  static final Logger logger = Logger();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Genshin Mod Manager',
      home: FutureBuilder(
        future: getAppState().timeout(
          sharedPreferencesAwaitTime,
          onTimeout: () {
            logger.e('Unable to obtain SharedPreference settings');
            return AppState.defaultState();
          },
        ),
        builder: (context, snapshot) {
          logger.d('App FutureBuilder snapshot status: $snapshot');
          if (!snapshot.hasData) {
            return buildLoadingScreen();
          }
          return buildMain(snapshot.data!);
        },
      ),
    );
  }

  Widget buildMain(AppState data) {
    return ChangeNotifierProvider.value(
      value: data,
      builder: (context, child) {
        final dirPath = context.select<AppState, String>(
            (value) => p.join(value.targetDir, modDir));
        final curExePath = Platform.resolvedExecutable;
        final curExeParentDir = p.dirname(curExePath);
        final modResourcePath = p.join(curExeParentDir, resourceDir);
        Directory(modResourcePath).createSync();
        return HomeWindow(dirPaths: [dirPath, modResourcePath]);
      },
    );
  }

  Widget buildLoadingScreen() {
    return const ScaffoldPage(
      content: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProgressRing(),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
