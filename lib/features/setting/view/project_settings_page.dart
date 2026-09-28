import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/cover_art_service.dart';
import 'package:karbeat/features/setting/services/project_settings_provider.dart';
import 'package:karbeat/features/setting/view/cover_crop_dialog.dart';
import 'package:karbeat/src/rust/api/project.dart';

class ProjectSettingsPage extends ConsumerStatefulWidget {
  const ProjectSettingsPage({super.key});

  @override
  ConsumerState<ProjectSettingsPage> createState() =>
      _ProjectSettingsPageState();
}

class _ProjectSettingsPageState extends ConsumerState<ProjectSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _genreController = TextEditingController();
  final _versionController = TextEditingController();

  late final ProviderSubscription<UiProjectMetadata?> _metadataSubscription;
  UiProjectMetadata? _sourceMetadata;
  UiProjectMetadata? _pendingMetadata;
  String? _coverPath;
  bool _dirty = false;
  bool _saving = false;
  bool _processingCover = false;

  Iterable<TextEditingController> get _controllers => [
    _titleController,
    _authorController,
    _descriptionController,
    _genreController,
    _versionController,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_updateDirtyState);
    }
    _metadataSubscription = ref.listenManual(
      projectSettingsProvider.select((state) => state.metadata),
      (_, metadata) {
        if (metadata != null) _receiveMetadata(metadata);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _metadataSubscription.close();
    for (final controller in _controllers) {
      controller
        ..removeListener(_updateDirtyState)
        ..dispose();
    }
    super.dispose();
  }

  void _receiveMetadata(UiProjectMetadata metadata) {
    final source = _sourceMetadata;
    if (source == metadata) return;
    if (_dirty && !_saving && source != null) {
      setState(() => _pendingMetadata = metadata);
      return;
    }
    _applyMetadata(metadata);
  }

  void _applyMetadata(UiProjectMetadata metadata) {
    _sourceMetadata = metadata;
    _pendingMetadata = null;
    _titleController.text = metadata.name;
    _authorController.text = metadata.author;
    _descriptionController.text = metadata.description;
    _genreController.text = metadata.genre;
    _versionController.text = metadata.version;
    _coverPath = metadata.coverPath;
    if (mounted) {
      setState(() => _dirty = false);
    } else {
      _dirty = false;
    }
  }

  void _updateDirtyState() {
    final source = _sourceMetadata;
    if (source == null || !mounted) return;
    final dirty =
        _titleController.text != source.name ||
        _authorController.text != source.author ||
        _descriptionController.text != source.description ||
        _genreController.text != source.genre ||
        _versionController.text != source.version ||
        _coverPath != source.coverPath;
    if (_dirty != dirty) setState(() => _dirty = dirty);
  }

  void _setCover(String? path) {
    setState(() => _coverPath = path);
    _updateDirtyState();
  }

  /// Picks an image, lets the user crop it square, and stages the encoded
  /// cover. Nothing reaches the project until the form is saved.
  Future<void> _chooseCover() async {
    final notifications = ref.read(notificationProvider.notifier);
    setState(() => _processingCover = true);
    final picked = await pickCoverSource();
    switch (picked) {
      case Error(:final error):
        notifications.error(error, title: 'Could not open the image');
      case Ok(value: final image?):
        if (mounted) await _cropAndStage(image);
        image.dispose();
      case Ok():
        break;
    }
    if (mounted) setState(() => _processingCover = false);
  }

  Future<void> _cropAndStage(ui.Image image) async {
    final crop = await CoverCropDialog.show(context, image);
    if (crop == null) return;
    final encoded = await encodeCoverCrop(image, crop);
    if (!mounted) return;
    switch (encoded) {
      case Ok(value: final path):
        _setCover(path);
      case Error(:final error):
        ref
            .read(notificationProvider.notifier)
            .error(error, title: 'Could not save the cover');
    }
  }

  Future<void> _save() async {
    final source = _sourceMetadata;
    if (source == null || !_dirty || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final result = await ref
        .read(projectProvider.notifier)
        .updateMetadata(
          UiProjectMetadata(
            name: _titleController.text,
            author: _authorController.text,
            description: _descriptionController.text,
            genre: _genreController.text,
            version: _versionController.text,
            createdAt: source.createdAt,
            coverPath: _coverPath,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isOk()) {
      final savedMetadata = ref.read(projectSettingsProvider).metadata;
      if (savedMetadata != null) _applyMetadata(savedMetadata);
      ref
          .read(notificationProvider.notifier)
          .info('Project information updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAvailable = ref.watch(
      projectSettingsProvider.select((state) => state.hasProject),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project',
                  key: const ValueKey('settings-page-project'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (_pendingMetadata != null) ...[
                  const SizedBox(height: 16),
                  _ProjectChangedBanner(
                    onReload: () => _applyMetadata(_pendingMetadata!),
                    onKeepEditing: () {
                      setState(() => _pendingMetadata = null);
                    },
                  ),
                ],
                const SizedBox(height: 24),
                if (!projectAvailable || _sourceMetadata == null)
                  const LinearProgressIndicator()
                else ...[
                  _CoverField(
                    path: _coverPath,
                    busy: _processingCover,
                    enabled: !_saving && !_processingCover,
                    onChoose: _chooseCover,
                    onRemove: () => _setCover(null),
                  ),
                  const SizedBox(height: 24),
                  _field(
                    controller: _titleController,
                    label: 'Title',
                    maximum: 120,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Title is required'
                        : null,
                  ),
                  _field(
                    controller: _authorController,
                    label: 'Author',
                    maximum: 120,
                    helperText: 'Separate multiple artists with ;',
                  ),
                  _field(
                    controller: _genreController,
                    label: 'Genre',
                    maximum: 80,
                  ),
                  _field(
                    controller: _versionController,
                    label: 'Project version',
                    maximum: 64,
                  ),
                  _field(
                    controller: _descriptionController,
                    label: 'Description',
                    maximum: 4000,
                    maxLines: 6,
                  ),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Created at',
                      border: OutlineInputBorder(),
                    ),
                    child: SelectableText(_sourceMetadata!.createdAt),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('save-project-metadata'),
                    onPressed: !_dirty || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save project info'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required int maximum,
    int maxLines = 1,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        maxLength: maximum,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Square cover preview with choose and remove actions
class _CoverField extends StatelessWidget {
  const _CoverField({
    required this.path,
    required this.busy,
    required this.enabled,
    required this.onChoose,
    required this.onRemove,
  });

  static const _previewExtent = 128.0;

  final String? path;
  final bool busy;
  final bool enabled;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Icons.album_outlined,
      size: 48,
      color: colors.onSurfaceVariant,
    );
    final path = this.path;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const ValueKey('project-cover-preview'),
          width: _previewExtent,
          height: _previewExtent,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: path == null
              ? placeholder
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cover art', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Square image embedded into exported audio',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('choose-project-cover'),
                    onPressed: enabled ? onChoose : null,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                    label: Text(path == null ? 'Choose image…' : 'Replace…'),
                  ),
                  if (path != null)
                    TextButton.icon(
                      key: const ValueKey('remove-project-cover'),
                      onPressed: enabled ? onRemove : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectChangedBanner extends StatelessWidget {
  const _ProjectChangedBanner({
    required this.onReload,
    required this.onKeepEditing,
  });

  final VoidCallback onReload;
  final VoidCallback onKeepEditing;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: const Text(
        'The current project changed while this form has unsaved edits.',
      ),
      actions: [
        TextButton(onPressed: onKeepEditing, child: const Text('Keep edits')),
        TextButton(onPressed: onReload, child: const Text('Reload project')),
      ],
    );
  }
}
