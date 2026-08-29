import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
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
  bool _dirty = false;
  bool _saving = false;

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
      projectProvider.select((state) => state.value?.metadata),
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
        _versionController.text != source.version;
    if (_dirty != dirty) setState(() => _dirty = dirty);
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
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isOk()) {
      ref
          .read(notificationProvider.notifier)
          .info('Project information updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAvailable = ref.watch(
      projectProvider.select((state) => state.hasValue),
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
          border: const OutlineInputBorder(),
        ),
      ),
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
