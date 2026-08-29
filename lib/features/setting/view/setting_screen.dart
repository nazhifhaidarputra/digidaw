import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/models/setting_state.dart';
import 'package:karbeat/features/setting/services/setting_provider.dart';
import 'package:karbeat/features/setting/view/general_settings_page.dart';
import 'package:karbeat/features/setting/view/appearance_settings_page.dart';
import 'package:karbeat/features/setting/view/info_settings_page.dart';
import 'package:karbeat/features/setting/view/log_settings_page.dart';
import 'package:karbeat/features/setting/view/project_settings_page.dart';

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
            tooltip: 'Close settings',
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
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

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder({required this.menu});

  final SettingMenu menu;

  @override
  Widget build(BuildContext context) {
    if (menu == SettingMenu.general) {
      return const GeneralSettingsPage();
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
                      Icon(
                        menu == SettingMenu.plugins
                            ? Icons.block
                            : Icons.construction,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          menu == SettingMenu.plugins
                              ? 'Third-party plugin scanning is unavailable until a plugin host is ready.'
                              : 'This settings page will be implemented in a later phase.',
                        ),
                      ),
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
  SettingMenu.general => 'General',
  SettingMenu.hostAndDevices => 'Host & Devices',
  SettingMenu.project => 'Project',
  SettingMenu.appearance => 'Appearance',
  SettingMenu.audio => 'Audio',
  SettingMenu.keyBinding => 'Key Bindings',
  SettingMenu.plugins => 'Plugins',
  SettingMenu.log => 'Logs',
  SettingMenu.info => 'Info',
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
  SettingMenu.general =>
    'Configure application-wide behavior such as undo history retention.',
  SettingMenu.hostAndDevices =>
    'Choose the audio host and output device. Input devices are not supported yet.',
  SettingMenu.project => 'Edit metadata stored with the current project.',
  SettingMenu.appearance =>
    'Personalize the application theme, colors, background, and typography.',
  SettingMenu.audio => 'Configure DSP processing sample rate and block size.',
  SettingMenu.keyBinding =>
    'Review and customize application keyboard shortcuts.',
  SettingMenu.plugins => 'Third-party plugin discovery and hosting settings.',
  SettingMenu.log =>
    'Configure diagnostics and inspect recent application logs.',
  SettingMenu.info =>
    'View application version, licenses, and bug-report information.',
};
