import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                'Host & Devices',
                key: const ValueKey('settings-page-hostAndDevices'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose where audio plays and which device audio tracks record from.',
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                key: ValueKey('output-host-${state.selectedHostName}'),
                isExpanded: true,
                initialValue: state.selectedHostName ?? _systemDefault,
                decoration: const InputDecoration(
                  labelText: 'Audio host',
                  border: OutlineInputBorder(),
                ),
                items: state.availableHosts.isEmpty
                    ? const [
                        DropdownMenuItem(
                          value: _systemDefault,
                          child: Text('System default'),
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
                decoration: const InputDecoration(
                  labelText: 'Output device',
                  border: OutlineInputBorder(),
                ),
                items: state.availableOutputDevices.isEmpty
                    ? const [
                        DropdownMenuItem(
                          value: _systemDefault,
                          child: Text('System default output'),
                        ),
                      ]
                    : state.availableOutputDevices
                          .map(
                            (device) => DropdownMenuItem(
                              value: device.deviceId ?? _systemDefault,
                              child: Text(
                                device.isCurrentSystemDefault &&
                                        device.deviceId != null
                                    ? '${device.displayName} (current default)'
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
                'Audio input',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('input-enabled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable audio input'),
                subtitle: const Text(
                  'Lets audio tracks record and monitor the input device. Arming a track turns it on.',
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Input device',
                  border: OutlineInputBorder(),
                ),
                items: state.availableInputDevices.isEmpty
                    ? const [
                        DropdownMenuItem(
                          value: _systemDefault,
                          child: Text('System default input'),
                        ),
                      ]
                    : state.availableInputDevices
                          .map(
                            (device) => DropdownMenuItem(
                              value: device.deviceId ?? _systemDefault,
                              child: Text(
                                device.isCurrentSystemDefault &&
                                        device.deviceId != null
                                    ? '${device.displayName} (current default)'
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
                  label: const Text('Retry input discovery'),
                ),
              ],
              if (state.runtimeSettings?.actualInput case final input?) ...[
                const SizedBox(height: 8),
                Text(
                  '${input.deviceName} · ${input.sampleRate} Hz · ${input.channels} channels',
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
                  label: const Text('Retry discovery'),
                ),
              ],
              if (state.fallbackReason != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${state.fallbackReason} System default output is active.',
                    ),
                  ),
                ),
              ],
              if (state.runtimeSettings?.actualStream case final actual?) ...[
                const SizedBox(height: 24),
                Text(
                  'Active device stream',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(actual.deviceName),
                Text(
                  '${actual.sampleRate} Hz · ${actual.callbackBufferSize} frames · ${actual.channels} channels',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
