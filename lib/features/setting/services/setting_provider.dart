import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/models/setting_state.dart';

class SettingsNotifier extends Notifier<SettingState> {
  @override
  SettingState build() => const SettingState();

  void selectMenu(SettingMenu menu) {
    if (state.selectedMenu == menu) return;
    state = state.copyWith(selectedMenu: menu);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingState>(
  SettingsNotifier.new,
);
