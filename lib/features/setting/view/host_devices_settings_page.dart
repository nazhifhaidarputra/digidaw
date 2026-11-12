import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/setting/services/host_devices_settings_provider.dart';

class HostDevicesSettingsPage extends ConsumerWidget {
  const HostDevicesSettingsPage({super.key});

  static const _systemDefault = '__system_default__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostDevicesSettingsProvider);
    final notifier = ref.read(hostDevicesSettingsProvider.notifier);
    final busy =
        state.isLoadingHosts ||
        state.isLoadingOutputDevices ||
        state.isApplyingSelection;
    final inputBusy =
        busy || state.isLoadingInputDevices || state.isApplyingInput;

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
                tr('settings-menu-host-devices'),
                key: const ValueKey('settings-page-hostAndDevices'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(tr('settings-host-description')),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                key: ValueKey('output-host-${state.selectedHostName}'),
                isExpanded: true,
                initialValue: state.selectedHostName ?? _systemDefault,
                decoration: InputDecoration(
                  labelText: tr('settings-host-audio-host'),
                  border: OutlineInputBorder(),
                ),
                items: state.availableHosts.isEmpty
                    ? [
                        DropdownMenuItem(
                          value: _systemDefault,
                          child: Text(tr('settings-host-system-default')),
                        ),
                      ]
                    : state.availableHosts
                          .map(
                            (host) => DropdownMenuItem(
                              value: host.hostName ?? _systemDefault,
                              child: Text(host.displayName),
                            ),
                          )
                          .toList(growable: false),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) {
                          unawaited(
                            notifier.selectHost(
                              value == _systemDefault ? null : value,
                            ),
                          );
                        }
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('output-device-${state.selectedOutputDeviceId}'),
                isExpanded: true,
                initialValue: state.selectedOutputDeviceId ?? _systemDefault,
                decoration: InputDecoration(
                  labelText: tr('settings-host-output-device'),
                  border: OutlineInputBorder(),
                ),
                items: state.availableOutputDevices.isEmpty
                    ? [
                        DropdownMenuItem(
                          value: _systemDefault,
                          child: Text(
                            tr('settings-host-system-default-output'),
                          ),
                        ),
                      ]
                    : state.availableOutputDevices
                          .map(
                            (device) => DropdownMenuItem(
                              value: device.deviceId ?? _systemDefault,
                              child: Text(
                                device.isCurrentSystemDefault &&
                                        device.deviceId != null
                                    ? tr('settings-host-current-default', {
                                        'device': device.displayName,
                                      })
                                    : device.displayName,
                              ),
                            ),
                          )
                          .toList(growable: false),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) {
                          unawaited(
                            notifier.selectOutputDevice(
                              value == _systemDefault ? null : value,
                            ),
                          );
                        }
                      },
              ),
              if (busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 32),
              Text(
                tr('settings-host-audio-input'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('input-enabled'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('settings-host-input-enable')),
                subtitle: Text(tr('settings-host-input-help')),
                value: state.inputEnabled,
                onChanged: inputBusy
                    ? null
                    : (enabled) => unawaited(notifier.setInputEnabled(enabled)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('input-device-${state.selectedInputDeviceId}'),
                isExpanded: true,
                initialValue: state.selectedInputDeviceId ?? _systemDefault,
                decoration: InputDecoration(
                  labelText: tr('settings-host-input-device'),
                  border: OutlineInputBorder(),
                ),
                items: state.availableInputDevices.isEmpty
                    ? [
                        DropdownMenuItem(
                          value: _systemDefault,
                          child: Text(tr('settings-host-system-default-input')),
                        ),
                      ]
                    : state.availableInputDevices
                          .map(
                            (device) => DropdownMenuItem(
                              value: device.deviceId ?? _systemDefault,
                              child: Text(
                                device.isCurrentSystemDefault &&
                                        device.deviceId != null
                                    ? tr('settings-host-current-default', {
                                        'device': device.displayName,
                                      })
                                    : device.displayName,
                              ),
                            ),
                          )
                          .toList(growable: false),
                onChanged: inputBusy
                    ? null
                    : (value) {
                        if (value != null) {
                          unawaited(
                            notifier.selectInputDevice(
                              value == _systemDefault ? null : value,
                            ),
                          );
                        }
                      },
              ),
              if (state.inputDiscoveryError != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.inputDiscoveryError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(notifier.reloadInputDevices()),
                  icon: const Icon(Icons.refresh),
                  label: Text(tr('settings-host-input-retry')),
                ),
              ],
              if (state.runtimeSettings?.actualInput case final input?) ...[
                const SizedBox(height: 8),
                Text(
                  tr('settings-host-stream-summary', {
                    'device': input.deviceName,
                    'rate': input.sampleRate,
                    'channels': input.channels,
                  }),
                ),
              ],
              if (state.discoveryError != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.discoveryError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(notifier.reloadOutputDevices()),
                  icon: const Icon(Icons.refresh),
                  label: Text(tr('settings-host-retry')),
                ),
              ],
              if (state.fallbackReason != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      tr('settings-host-fallback-active', {
                        'reason': state.fallbackReason ?? '',
                      }),
                    ),
                  ),
                ),
              ],
              if (state.runtimeSettings?.actualStream case final actual?) ...[
                const SizedBox(height: 24),
                Text(
                  tr('settings-host-active-stream'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(actual.deviceName),
                Text(
                  tr('settings-host-active-stream-summary', {
                    'rate': actual.sampleRate,
                    'frames': actual.callbackBufferSize,
                    'channels': actual.channels,
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
