import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/app_info_service.dart';

class InfoSettingsPage extends ConsumerWidget {
  const InfoSettingsPage({super.key});

  static const supportUrl = 'https://codeberg.org/haidarptrw/digidaw/issues';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageMetadata = ref.watch(appPackageMetadataProvider);

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
                'Info',
                key: const ValueKey('settings-page-info'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'DigiDAW is a cross-platform digital audio workstation powered by Flutter and Rust.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              _InfoCard(
                title: 'Application',
                child: packageMetadata.when(
                  data: (metadata) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Name', value: 'DigiDAW'),
                      _InfoRow(label: 'Version', value: metadata.version),
                      _InfoRow(
                        label: 'Build',
                        value: metadata.buildNumber.isEmpty
                            ? 'Not specified'
                            : metadata.buildNumber,
                      ),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Row(
                    children: [
                      const Expanded(
                        child: Text('Version information is unavailable.'),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(appPackageMetadataProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Report a bug',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Include your DigiDAW version, operating system, steps to reproduce, expected result, actual result, and relevant logs.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: SelectableText(supportUrl)),
                        IconButton(
                          tooltip: 'Copy bug report URL',
                          onPressed: () => _copySupportUrl(ref),
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Open-source licenses',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'DigiDAW',
                    ),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('View licenses'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copySupportUrl(WidgetRef ref) async {
    final result = await attemptAsync(
      () => Clipboard.setData(const ClipboardData(text: supportUrl)),
    );
    if (result.isErr()) {
      ref
          .read(notificationProvider.notifier)
          .error(result.err(), title: 'Could not copy URL');
      return;
    }
    ref.read(notificationProvider.notifier).info('Bug report URL copied');
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
