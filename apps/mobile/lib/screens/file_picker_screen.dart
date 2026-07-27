import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';
import '../widgets/neon_button.dart';

class SelectedFileItem {
  final String name;
  final int sizeBytes;
  final String sizeFormatted;
  final String? path;
  final IconData icon;
  bool isSelected;

  SelectedFileItem({
    required this.name,
    required this.sizeBytes,
    required this.sizeFormatted,
    this.path,
    required this.icon,
    this.isSelected = true,
  });
}

class FilePickerScreen extends StatefulWidget {
  final Function(List<SelectedFileItem> files) onSend;

  const FilePickerScreen({super.key, required this.onSend});

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  final List<SelectedFileItem> _items = [];

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final file in result.files) {
            final icon = _getIconForFile(file.name);
            final formattedSize = _formatBytes(file.size);
            _items.add(
              SelectedFileItem(
                name: file.name,
                sizeBytes: file.size,
                sizeFormatted: formattedSize,
                path: file.path,
                icon: icon,
                isSelected: true,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: $e')),
        );
      }
    }
  }

  IconData _getIconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'webm':
        return Icons.movie_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.music_note_rounded;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_rounded;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'apk':
      case 'exe':
      case 'dmg':
      case 'deb':
        return Icons.android_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(2)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
    final selectedList = _items.where((i) => i.isSelected).toList();
    final int selectedCount = selectedList.length;
    final int totalBytes =
        selectedList.fold(0, (sum, item) => sum + item.sizeBytes);
    final String formattedTotalSize = _formatBytes(totalBytes);

    return Scaffold(
      backgroundColor: SwiftBeamColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: SwiftBeamColors.backgroundAmbientGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Top Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Files to Send',
                            style: SwiftBeamTypography.headlineMedium),
                        Text(
                            'Native cross-platform file picker (Android, iOS, Web, Desktop)',
                            style: SwiftBeamTypography.bodyMedium),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Native Browse / Add Files Card
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  onTap: _pickFiles,
                  borderColor:
                      SwiftBeamColors.primaryCyan.withValues(alpha: 0.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: SwiftBeamColors.primaryCyan,
                        ),
                        child: const Icon(Icons.file_open_rounded,
                            color: SwiftBeamColors.background, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Browse & Pick Files',
                              style: SwiftBeamTypography.titleMedium),
                          Text('Opens native system file dialog',
                              style: SwiftBeamTypography.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // File List
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: GlassContainer(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_open_rounded,
                                    color: Colors.white38, size: 48),
                                SizedBox(height: 12),
                                Text('No Files Selected',
                                    style: SwiftBeamTypography.titleMedium),
                                SizedBox(height: 4),
                                Text(
                                  'Tap "Browse & Pick Files" above to select files from your device.',
                                  textAlign: TextAlign.center,
                                  style: SwiftBeamTypography.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return GlassContainer(
                              padding: const EdgeInsets.all(16),
                              onTap: () {
                                setState(() {
                                  item.isSelected = !item.isSelected;
                                });
                              },
                              borderColor: item.isSelected
                                  ? SwiftBeamColors.primaryCyan
                                      .withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.1),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: item.isSelected,
                                    activeColor: SwiftBeamColors.primaryCyan,
                                    checkColor: SwiftBeamColors.background,
                                    onChanged: (val) {
                                      setState(() {
                                        item.isSelected = val ?? false;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: SwiftBeamColors.primaryCyan
                                          .withValues(alpha: 0.15),
                                    ),
                                    child: Icon(item.icon,
                                        color: SwiftBeamColors.primaryCyan,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            style:
                                                SwiftBeamTypography.titleMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text(item.sizeFormatted,
                                            style:
                                                SwiftBeamTypography.bodyMedium),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: Colors.white38),
                                    onPressed: () {
                                      setState(() {
                                        _items.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),

                // Dynamic Action Button
                NeonButton(
                  label: selectedCount > 0
                      ? 'Send ($selectedCount ${selectedCount == 1 ? "File" : "Files"} - $formattedTotalSize)'
                      : 'Select Files First',
                  icon: Icons.send_rounded,
                  onPressed: selectedCount > 0
                      ? () => widget.onSend(selectedList)
                      : _pickFiles,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
