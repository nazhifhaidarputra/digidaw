import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/state/app_state.dart';
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
  String _exportDirectory = "Select Directory...";
  String _selectedFormat = "WAV";
  int _selectedBitDepth = 16;
  int _selectedBitrate = 192;
  String _tailHandling = "Leave Tail";
  bool _openFolderAfterExport = true;

  bool _isExporting = false;
  double _exportProgress = 0.0;

  @override
  void initState() {
    super.initState();
    final state = ref.read(karbeatStateProvider);
    _nameController = TextEditingController(text: state.metadata.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _exportDirectory = selectedDirectory;
      });
    }
  }

  Future<void> _handleExport() async {
    if (_exportDirectory == "Select Directory...") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an export directory first.")),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    // Mock progress to simulate backend rendering
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _exportProgress = i / 10.0;
      });
    }

    // TODO: Call your actual backend export API via karbeatStateProvider here
    // final state = ref.read(karbeatStateProvider);
    // await state.exportProject(...);

    setState(() {
      _isExporting = false;
    });

    if (_openFolderAfterExport) {
       // Best effort to open folder (works mostly on desktop platforms)
       if (Platform.isWindows) {
         Process.run('explorer.exe', [_exportDirectory]);
       } else if (Platform.isMacOS) {
         Process.run('open', [_exportDirectory]);
       } else if (Platform.isLinux) {
         Process.run('xdg-open', [_exportDirectory]);
       }
    }

    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(karbeatStateProvider);
    final size = MediaQuery.of(context).size;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.5,
          height: size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
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
                    Text(
                      "Export Project",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                      _buildSectionTitle("Export Directory"),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _exportDirectory,
                                style: TextStyle(
                                  color: _exportDirectory == "Select Directory..." 
                                      ? Colors.white54 
                                      : Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isExporting ? null : _pickDirectory,
                            icon: const Icon(Icons.folder_open),
                            label: const Text("Browse"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
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
                                _buildDropdown<String>(
                                  value: _selectedFormat,
                                  items: ["WAV", "MP3", "OGG", "FLAC"],
                                  onChanged: (val) => setState(() => _selectedFormat = val!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle("Bit Depth / Bitrate"),
                                if (_selectedFormat == "WAV" || _selectedFormat == "FLAC")
                                  _buildDropdown<int>(
                                    value: _selectedBitDepth,
                                    items: [16, 24, 32],
                                    suffix: "-bit",
                                    onChanged: (val) => setState(() => _selectedBitDepth = val!),
                                  )
                                else
                                  _buildDropdown<int>(
                                    value: _selectedBitrate,
                                    items: [128, 192, 256, 320],
                                    suffix: " kbps",
                                    onChanged: (val) => setState(() => _selectedBitrate = val!),
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
                                _buildDropdown<String>(
                                  value: _tailHandling,
                                  items: ["Leave Tail", "Cut Remainder", "Wrap Remainder"],
                                  onChanged: (val) => setState(() => _tailHandling = val!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Options
                      Row(
                        children: [
                          Checkbox(
                            value: _openFolderAfterExport,
                            activeColor: Colors.blueAccent,
                            onChanged: _isExporting ? null : (val) => setState(() => _openFolderAfterExport = val!),
                          ),
                          const Text(
                            "Open folder after export",
                            style: TextStyle(color: Colors.white70),
                          ),
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
                      ]
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
        style: TextStyle(
          color: Colors.grey.shade400,
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
    String suffix = "",
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.grey.shade800,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          style: const TextStyle(color: Colors.white),
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text("$item$suffix"),
            );
          }).toList(),
          onChanged: _isExporting ? null : onChanged,
        ),
      ),
    );
  }
}