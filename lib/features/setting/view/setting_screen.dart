import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/setting/models/setting_state.dart';
import 'package:karbeat/features/setting/services/setting_provider.dart';
import 'package:karbeat/features/setting/view/general_settings_page.dart';
import 'package:karbeat/features/setting/view/host_devices_settings_page.dart';
import 'package:karbeat/features/setting/view/appearance_settings_page.dart';
import 'package:karbeat/features/setting/view/audio_settings_page.dart';
import 'package:karbeat/features/setting/view/info_settings_page.dart';
import 'package:karbeat/features/setting/view/key_binding_settings_page.dart';
import 'package:karbeat/features/setting/view/log_settings_page.dart';
import 'package:karbeat/features/setting/view/project_settings_page.dart';
import 'package:karbeat/features/setting/view/plugin_settings_page.dart';

class SettingScreen extends ConsumerWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMenu = ref.watch(
      settingsProvider.select((state) => state.selectedMenu),
    );
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _SettingsHeader(onClose: () => Navigator.of(context).maybePop()),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 230,
                    child: _SettingsMenu(
                      selectedMenu: selectedMenu,
                      onSelected: ref
                          .read(settingsProvider.notifier)
                          .selectMenu,
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colors.outlineVariant,
                  ),
                  Expanded(child: _SettingsPlaceholder(menu: selectedMenu)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: tr('settings-close'),
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Text(
            tr('settings-title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({required this.selectedMenu, required this.onSelected});

  final SettingMenu selectedMenu;
  final ValueChanged<SettingMenu> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: SettingMenu.values
            .map((menu) {
              final selected = menu == selectedMenu;
              return ListTile(
                key: ValueKey(menu),
                dense: true,
                selected: selected,
                selectedTileColor: colors.primaryContainer,
                leading: Icon(_iconFor(menu), size: 20),
                title: Text(_labelFor(menu)),
                onTap: () => onSelected(menu),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _SettingsPlaceholder extends ConsumerWidget {
  const _SettingsPlaceholder({required this.menu});

  final SettingMenu menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (menu == SettingMenu.general) {
      return const GeneralSettingsPage();
    }
    if (menu == SettingMenu.hostAndDevices) {
      return const HostDevicesSettingsPage();
    }
    if (menu == SettingMenu.info) {
      return const InfoSettingsPage();
    }
    if (menu == SettingMenu.project) {
      return const ProjectSettingsPage();
    }
    if (menu == SettingMenu.log) {
      return const LogSettingsPage();
    }
    if (menu == SettingMenu.appearance) {
      return const AppearanceSettingsPage();
    }
    if (menu == SettingMenu.audio) {
      return const AudioSettingsPage();
    }
    if (menu == SettingMenu.keyBinding) {
      return const KeyBindingSettingsPage();
    }
    if (menu == SettingMenu.plugins) {
      return const PluginSettingsPage();
    }

    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _labelFor(menu),
                key: ValueKey('settings-page-${menu.name}'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                _descriptionFor(menu),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.construction, color: colors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tr('settings-page-placeholder'))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _labelFor(SettingMenu menu) => switch (menu) {
  SettingMenu.general => tr('settings-menu-general'),
  SettingMenu.hostAndDevices => tr('settings-menu-host-devices'),
  SettingMenu.project => tr('settings-menu-project'),
  SettingMenu.appearance => tr('settings-menu-appearance'),
  SettingMenu.audio => tr('settings-menu-audio'),
  SettingMenu.keyBinding => tr('settings-menu-key-bindings'),
  SettingMenu.plugins => tr('settings-menu-plugins'),
  SettingMenu.log => tr('settings-menu-logs'),
  SettingMenu.info => tr('settings-menu-info'),
};

IconData _iconFor(SettingMenu menu) => switch (menu) {
  SettingMenu.general => Icons.tune,
  SettingMenu.hostAndDevices => Icons.speaker,
  SettingMenu.project => Icons.description_outlined,
  SettingMenu.appearance => Icons.palette_outlined,
  SettingMenu.audio => Icons.graphic_eq,
  SettingMenu.keyBinding => Icons.keyboard_outlined,
  SettingMenu.plugins => Icons.extension_outlined,
  SettingMenu.log => Icons.receipt_long_outlined,
  SettingMenu.info => Icons.info_outline,
};

String _descriptionFor(SettingMenu menu) => switch (menu) {
  SettingMenu.general => tr('settings-menu-general-description'),
  SettingMenu.hostAndDevices => tr('settings-menu-host-devices-description'),
  SettingMenu.project => tr('settings-menu-project-description'),
  SettingMenu.appearance => tr('settings-menu-appearance-description'),
  SettingMenu.audio => tr('settings-menu-audio-description'),
  SettingMenu.keyBinding => tr('settings-menu-key-bindings-description'),
  SettingMenu.plugins => tr('settings-menu-plugins-description'),
  SettingMenu.log => tr('settings-menu-logs-description'),
  SettingMenu.info => tr('settings-menu-info-description'),
};
