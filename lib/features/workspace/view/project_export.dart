import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/export_project_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/constants/audio_format.dart';
import 'package:karbeat/features/workspace/services/export_service.dart';
import 'package:karbeat/shared/models/export_audio.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/app/providers/app_state.dart';
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
    _nameController = TextEditingController(text: projectState?.metadata.name ?? 'Untitled');

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
      ref.read(exportProjectProvider.notifier).updateExportDirectory(file.parent.path);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select an export directory first.")));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
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
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 20, spreadRadius: 5)],
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Export Project",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade800,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Directory
                      _buildSectionTitle("Export Location"),
                      TextField(
                        readOnly: true,
                        style: TextStyle(color: exportState.exportDirectory == null ? Colors.white54 : Colors.white),
                        decoration: InputDecoration(
                          hintText: "Select Directory...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.grey.shade800,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          // The three dots button
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.more_horiz, color: Colors.white70),
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
                      const Divider(color: Colors.white24),
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
                                  items: const [SupportedAudioFormat.wav, SupportedAudioFormat.mp3],
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
                                      exportState.selectedFormat == SupportedAudioFormat.wav ||
                                          exportState.selectedFormat == SupportedAudioFormat.flac
                                      ? bitPerSampleOptions
                                      : bitPerSecondOptions,
                                  itemLabel: (b) => switch (b) {
                                    BitDepthDTO_BitPerSample(:final field0) => field0.toString(),
                                    BitDepthDTO_BitPerSecond(:final field0) => field0.toString(),
                                  },
                                  suffix:
                                      exportState.selectedFormat == SupportedAudioFormat.wav ||
                                          exportState.selectedFormat == SupportedAudioFormat.flac
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
                                  itemLabel: (t) => t.name.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' '),
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
                            activeColor: Colors.blueAccent,
                            onChanged: _isExporting
                                ? null
                                : (val) {
                                    if (val != null) {
                                      exportNotifier.setOpenFolderAfterExport(val);
                                    }
                                  },
                          ),
                          const Text("Open folder after export", style: TextStyle(color: Colors.white70)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Progress Bar
                      if (_isExporting) ...[
                        Text(
                          "Rendering: ${(_exportProgress * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _exportProgress,
                          backgroundColor: Colors.grey.shade800,
                          color: Colors.greenAccent,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer / Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade800)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isExporting ? null : widget.onClose,
                      child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isExporting ? null : _handleExport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.grey.shade800,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          style: const TextStyle(color: Colors.white),
          items: items.map((T item) {
            return DropdownMenuItem<T>(value: item, child: Text("${itemLabel(item)}$suffix"));
          }).toList(),
          onChanged: _isExporting ? null : onChanged,
        ),
      ),
    );
  }
}
