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
                'Configure output audio only. Input device selection and recording inputs are not available yet.',
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
