import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../backend/storage/domain/usecase/dark_mode.dart';
import '../storage.dart';
import 'value_settable.dart';

part 'dark_mode.g.dart';

@riverpod
class DarkMode extends _$DarkMode implements ValueSettable<bool> {
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
