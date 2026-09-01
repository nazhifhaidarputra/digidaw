import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/export_project_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/constants/audio_format.dart';
import 'package:karbeat/features/workspace/services/export_service.dart';
import 'package:karbeat/shared/models/export_audio.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:file_picker/file_picker.dart';

class ProjectExportPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const ProjectExportPanel({super.key, required this.onClose});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _ProjectExportPanelState();
  }
}

class _ProjectExportPanelState extends ConsumerState<ProjectExportPanel> {
  late TextEditingController _nameController;

  bool _isExporting = false;
  double _exportProgress = 0.0;

  @override
  void initState() {
    super.initState();
    final projectState = ref.read(projectProvider).value;
    _nameController = TextEditingController(
      text: projectState?.metadata.name ?? 'Untitled',
    );

    // Ensure the export directory text field updates dynamically when typing the name
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickSavePath() async {
    final exportState = ref.read(exportProjectProvider);
    final format = exportState.selectedFormat;

    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Select export location and name',
      fileName: '${_nameController.text}.${format.name.toLowerCase()}',
      type: FileType.custom,
      allowedExtensions: [format.name.toLowerCase()],
    );

    if (outputFile != null) {
      final file = File(outputFile);

      // Update global export state
      ref
          .read(exportProjectProvider.notifier)
          .updateExportDirectory(file.parent.path);

      // Extract filename without extension to cleanly update the local name controller
      final nameWithExt = file.uri.pathSegments.last;
      final nameWithoutExt = nameWithExt.contains('.')
          ? nameWithExt.substring(0, nameWithExt.lastIndexOf('.'))
          : nameWithExt;
      _nameController.text = nameWithoutExt;
    }
  }

  Future<void> _handleExport() async {
    final exportState = ref.read(exportProjectProvider);

    final ctx = ref.read(projectProvider.notifier).dawContext;

    if (exportState.exportDirectory == null) {
      ref
          .read(notificationProvider.notifier)
          .warn('Please select an export directory first.');
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    try {
      // Consume the progress stream using values straight from the provider state
      final progressStream = exportProject(
        ctx: ctx,
        path: exportState.exportDirectory!,
        soundfileName: _nameController.text,
        format: exportState.selectedFormat,
        bitDepth: exportState.selectedBitDepth,
        sampleRate: exportState.selectedSampleRate,
        tailHandling: exportState.tailHandling,
      );

      await for (final progress in progressStream) {
        if (!mounted) break;
        setState(() {
          _exportProgress = progress;
        });
      }
    } catch (e) {
      ref.read(notificationProvider.notifier).error(e, title: 'Export failed');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }

    if (exportState.openFolderAfterExport && mounted) {
      // Best effort to open folder
      if (Platform.isWindows) {
        Process.run('explorer.exe', [exportState.exportDirectory!]);
      } else if (Platform.isMacOS) {
        Process.run('open', [exportState.exportDirectory!]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [exportState.exportDirectory!]);
      }
    }

    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final exportState = ref.watch(exportProjectProvider);
    final exportNotifier = ref.read(exportProjectProvider.notifier);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.5,
          height: size.height * 0.65,
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Export Project",
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                      onPressed: _isExporting ? null : widget.onClose,
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    children: [
                      // File Name
                      _buildSectionTitle("File Name"),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: colors.onSurface),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colors.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Directory
                      _buildSectionTitle("Export Location"),
                      TextField(
                        readOnly: true,
                        style: TextStyle(
                          color: exportState.exportDirectory == null
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: "Select Directory...",
                          hintStyle: TextStyle(color: colors.onSurfaceVariant),
                          filled: true,
                          fillColor: colors.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          // The three dots button
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.more_horiz,
                              color: colors.onSurfaceVariant,
                            ),
                            onPressed: _isExporting ? null : _pickSavePath,
                          ),
                        ),
                        controller: TextEditingController(
                          text: exportState.exportDirectory == null
                              ? ""
                              : "${exportState.exportDirectory}${Platform.pathSeparator}${_nameController.text}.${exportState.selectedFormat.name.toLowerCase()}",
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(color: colors.outlineVariant),
                      const SizedBox(height: 16),

                      // Format Settings Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle("Format"),
                                _buildDropdown<SupportedAudioFormat>(
                                  value: exportState.selectedFormat,
                                  items: const [
                                    SupportedAudioFormat.wav,
                                    SupportedAudioFormat.mp3,
                                  ],
                                  itemLabel: (f) => f.name.toUpperCase(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      exportNotifier.updateFormat(val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle("Sample Rate"),
                                _buildDropdown<SampleRate>(
                                  value: exportState.selectedSampleRate,
                                  items: SampleRate.values,
                                  itemLabel: (s) => s.label,
                                  onChanged: (val) {
                                    if (val != null) {
                                      exportNotifier.updateSampleRate(val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Format Settings - Row 2 (Bit Depth/Rate & Tail Handling)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle("Bit Depth / Bitrate"),
                                _buildDropdown<BitDepthDTO>(
                                  value: exportState.selectedBitDepth,
                                  items:
                                      exportState.selectedFormat ==
                                              SupportedAudioFormat.wav ||
                                          exportState.selectedFormat ==
                                              SupportedAudioFormat.flac
                                      ? bitPerSampleOptions
                                      : bitPerSecondOptions,
                                  itemLabel: (b) => switch (b) {
                                    BitDepthDTO_BitPerSample(:final field0) =>
                                      field0.toString(),
                                    BitDepthDTO_BitPerSecond(:final field0) =>
                                      field0.toString(),
                                  },
                                  suffix:
                                      exportState.selectedFormat ==
                                              SupportedAudioFormat.wav ||
                                          exportState.selectedFormat ==
                                              SupportedAudioFormat.flac
                                      ? "-bit"
                                      : " kbps",
                                  onChanged: (val) {
                                    if (val != null) {
                                      exportNotifier.updateBitDepth(val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle("Tail Handling"),
                                _buildDropdown<TailHandling>(
                                  value: exportState.tailHandling,
                                  items: TailHandling.values,
                                  itemLabel: (t) => t.name.replaceAll(
                                    RegExp(r'(?<!^)(?=[A-Z])'),
                                    ' ',
                                  ),
                                  onChanged: (val) {
                                    if (val != null) {
                                      exportNotifier.updateTailHandling(val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Options
                      Row(
                        children: [
                          Checkbox(
                            value: exportState.openFolderAfterExport,
                            activeColor: colors.primary,
                            onChanged: _isExporting
                                ? null
                                : (val) {
                                    if (val != null) {
                                      exportNotifier.setOpenFolderAfterExport(
                                        val,
                                      );
                                    }
                                  },
                          ),
                          Text(
                            "Open folder after export",
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Progress Bar
                      if (_isExporting) ...[
                        Text(
                          "Rendering: ${(_exportProgress * 100).toInt()}%",
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _exportProgress,
                          backgroundColor: colors.surfaceContainerHighest,
                          color: colors.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer / Actions
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isExporting ? null : widget.onClose,
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isExporting ? null : _handleExport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      child: _isExporting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimary,
                              ),
                            )
                          : const Text("Export Audio"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemLabel,
    String suffix = "",
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: colors.surfaceContainerHigh,
          icon: Icon(Icons.arrow_drop_down, color: colors.onSurfaceVariant),
          style: TextStyle(color: colors.onSurface),
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text("${itemLabel(item)}$suffix"),
            );
          }).toList(),
          onChanged: _isExporting ? null : onChanged,
        ),
      ),
    );
  }
}
