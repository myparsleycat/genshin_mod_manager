import 'package:genshin_mod_manager/data/repo/sharedpreference_storage.dart';
import 'package:genshin_mod_manager/domain/entity/game_config.dart';
import 'package:genshin_mod_manager/domain/entity/preset.dart';
import 'package:genshin_mod_manager/domain/repo/persistent_storage.dart';
import 'package:genshin_mod_manager/domain/usecase/app_state/dark_mode.dart';
import 'package:genshin_mod_manager/domain/usecase/app_state/enabled_first.dart';
import 'package:genshin_mod_manager/domain/usecase/app_state/folder_icon.dart';
import 'package:genshin_mod_manager/domain/usecase/app_state/game_config.dart';
import 'package:genshin_mod_manager/domain/usecase/app_state/move_on_drag.dart';
import 'package:genshin_mod_manager/domain/usecase/app_state/run_together.dart';
import 'package:genshin_mod_manager/domain/usecase/storage/shared_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_state.g.dart';

/// The shared preference.
@riverpod
Future<SharedPreferences> sharedPreference(
  final SharedPreferenceRef ref,
) =>
    SharedPreferences.getInstance().timeout(const Duration(seconds: 5));

/// The storage for the shared preference.
@riverpod
PersistentStorage sharedPreferenceStorage(
  final SharedPreferenceStorageRef ref,
) {
  final sharedPreferences =
      ref.watch(sharedPreferenceProvider).unwrapPrevious().valueOrNull;
  if (sharedPreferences == null) {
    return NullSharedPreferenceStorage();
  }
  final sharedPreferenceStorage = SharedPreferenceStorage(sharedPreferences);
  afterInitializationUseCase(sharedPreferenceStorage);
  return sharedPreferenceStorage;
}

@riverpod
class GamesList extends _$GamesList {
  @override
  List<String> build() {
    final storage = ref.watch(sharedPreferenceStorageProvider);
    final gamesList = storage.getList('games');
    if (gamesList == null) {
      return [];
    }
    return gamesList;
  }

  void addGame(final String game) {
    final storage = ref.read(sharedPreferenceStorageProvider);
    if (state.contains(game)) {
      return;
    }
    final newGamesList = [...state, game];
    storage.setList('games', newGamesList);
    state = newGamesList;
  }

  void removeGame(final String game) {
    final storage = ref.read(sharedPreferenceStorageProvider);
    if (!state.contains(game)) {
      return;
    }
    final newGamesList = state.where((e) => e != game).toList();
    storage.setList('games', newGamesList);
    state = newGamesList;
  }
}

/// The target game.
@riverpod
class TargetGame extends _$TargetGame {
  @override
  String build() {
    final storage = ref.watch(sharedPreferenceStorageProvider);
    final gamesList = ref.watch(gamesListProvider);
    final lastGame = storage.getString('lastGame');
    if (gamesList.contains(lastGame)) {
      return lastGame!;
    } else {
      return gamesList.first;
    }
  }

  /// Sets the value.
  void setValue(final String value) {
    final read = ref.read(sharedPreferenceStorageProvider);
    final gamesList = ref.read(gamesListProvider);
    if (!gamesList.contains(value)) {
      return;
    }
    read.setString('lastGame', value);
    state = value;
  }
}

/// The notifier for the app state.
@riverpod
class GameConfigNotifier extends _$GameConfigNotifier {
  @override
  GameConfig build() {
    final storage2 = ref.watch(sharedPreferenceStorageProvider);
    final targetGame = ref.watch(targetGameProvider);
    final gameConfig = initializeGameConfigUseCase(storage2, targetGame);
    return gameConfig;
  }

  /// Changes the mod root.
  void changeModRoot(final String path) {
    final read = ref.read(sharedPreferenceStorageProvider);
    final targetGame = ref.read(targetGameProvider);
    changeModRootUseCase(read, targetGame, path);
    state = state.copyWith(modRoot: path);
  }

  /// Changes the mod executable file.
  void changeModExecFile(final String path) {
    final read = ref.read(sharedPreferenceStorageProvider);
    final targetGame = ref.read(targetGameProvider);
    changeModExecFileUseCase(read, targetGame, path);
    state = state.copyWith(modExecFile: path);
  }

  /// Changes the launcher file.
  void changeLauncherFile(final String path) {
    final read = ref.read(sharedPreferenceStorageProvider);
    final targetGame = ref.read(targetGameProvider);
    changeLauncherFileUseCase(read, targetGame, path);
    state = state.copyWith(launcherFile: path);
  }

  /// Changes the preset data.
  void changePresetData(final PresetData data) {
    final read = ref.read(sharedPreferenceStorageProvider);
    final targetGame = ref.read(targetGameProvider);
    changePresetDataUseCase(data, read, targetGame);
    state = state.copyWith(presetData: data);
  }
}

/// The notifier for boolean value.
mixin ValueSettable on AutoDisposeNotifier<bool> {
  /// Sets the value.
  void setValue(final bool value);
}

/// The notifier for the dark mode.
@riverpod
class DarkMode extends _$DarkMode with ValueSettable {
  @override
  bool build() {
    final watch = ref.watch(sharedPreferenceStorageProvider);
    return initializeDarkModeUseCase(watch);
  }

  @override
  void setValue(final bool value) {
    final read = ref.read(sharedPreferenceStorageProvider);
    setDarkModeUseCase(read, value);
    state = value;
  }
}

/// The notifier for the enabled first.
@riverpod
class EnabledFirst extends _$EnabledFirst with ValueSettable {
  @override
  bool build() {
    final watch = ref.watch(sharedPreferenceStorageProvider);
    final showEnabledModsFirst = initializeEnabledFirstUseCase(watch);
    return showEnabledModsFirst;
  }

  @override
  void setValue(final bool value) {
    final read = ref.read(sharedPreferenceStorageProvider);
    setEnabledFirstUseCase(read, value);
    state = value;
  }
}

/// The notifier for the folder icon.
@riverpod
class FolderIcon extends _$FolderIcon with ValueSettable {
  @override
  bool build() {
    final watch = ref.watch(sharedPreferenceStorageProvider);
    return initializeFolderIconUseCase(watch);
  }

  @override
  void setValue(final bool value) {
    final read = ref.read(sharedPreferenceStorageProvider);
    setFolderIconUseCase(read, value);
    state = value;
  }
}

/// The notifier for the move on drag.
@riverpod
class MoveOnDrag extends _$MoveOnDrag with ValueSettable {
  @override
  bool build() {
    final watch = ref.watch(sharedPreferenceStorageProvider);
    return initializeMoveOnDragUseCase(watch);
  }

  @override
  void setValue(final bool value) {
    final read = ref.read(sharedPreferenceStorageProvider);
    setMoveOnDragUseCase(read, value);
    state = value;
  }
}

/// The notifier for the run together.
@riverpod
class RunTogether extends _$RunTogether with ValueSettable {
  @override
  bool build() {
    final watch = ref.watch(sharedPreferenceStorageProvider);
    return initializeRunTogetherUseCase(watch);
  }

  @override
  void setValue(final bool value) {
    final read = ref.read(sharedPreferenceStorageProvider);
    setRunTogetherUseCase(read, value);
    state = value;
  }
}
