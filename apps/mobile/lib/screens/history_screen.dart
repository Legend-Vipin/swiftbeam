import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/transfer_history.dart';
import '../providers/history_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';

enum HistoryFilter { all, sent, received, success, failed }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  HistoryFilter _selectedFilter = HistoryFilter.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    final mbs = bytes / (1024 * 1024);
    if (mbs >= 1.0) {
      return "${mbs.toStringAsFixed(1)} MB";
    }
    final kbs = bytes / 1024;
    return "${kbs.toStringAsFixed(0)} KB";
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  List<TransferHistoryRecord> _filterRecords(
      List<TransferHistoryRecord> records) {
    return records.where((item) {
      // Search text match
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          item.fileName.toLowerCase().contains(query) ||
          item.peerName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      // Filter category match
      switch (_selectedFilter) {
        case HistoryFilter.all:
          return true;
        case HistoryFilter.sent:
          return item.direction == TransferDirection.send;
        case HistoryFilter.received:
          return item.direction == TransferDirection.receive;
        case HistoryFilter.success:
          return item.status == TransferStatus.completed;
        case HistoryFilter.failed:
          return item.status == TransferStatus.failed;
      }
    }).toList();
  }

  void _showRecordDetails(TransferHistoryRecord item) {
    final isSent = item.direction == TransferDirection.send;
    final isCompleted = item.status == TransferStatus.completed;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSent ? Icons.upload_rounded : Icons.download_rounded,
                  color: isSent
                      ? SwiftBeamColors.primaryCyan
                      : SwiftBeamColors.accentPurple,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.fileName,
                    style: SwiftBeamTypography.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            _buildDetailRow('Transfer ID', item.id),
            _buildDetailRow(
                'Direction', isSent ? 'Sent (Upload)' : 'Received (Download)'),
            _buildDetailRow('File Size', _formatSize(item.fileSize)),
            _buildDetailRow('Peer Device', item.peerName),
            _buildDetailRow(
                'Status', isCompleted ? 'Completed (Success)' : 'Failed'),
            _buildDetailRow(
                'Date & Time', item.timestamp.toString().split('.').first),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5D73),
                  side: const BorderSide(color: Color(0xFFFF5D73)),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete from History'),
                onPressed: () {
                  ref.read(historyProvider.notifier).removeRecord(item.id);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawHistory = ref.watch(historyProvider);
    final filteredHistory = _filterRecords(rawHistory);

    return Container(
      decoration: const BoxDecoration(
        gradient: SwiftBeamColors.backgroundAmbientGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer History',
                        style: SwiftBeamTypography.headlineMedium,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Past sent and received files over P2P network',
                        style: SwiftBeamTypography.bodyMedium,
                      ),
                    ],
                  ),
                  if (rawHistory.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_sweep_rounded,
                        color: Color(0xFFFF5D73),
                      ),
                      tooltip: 'Clear All History',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF111827),
                            title: const Text(
                              'Clear History?',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'This will remove all transfer history records from this device.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(historyProvider.notifier)
                                      .clearHistory();
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  'Clear All',
                                  style: TextStyle(color: Color(0xFFFF5D73)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Input
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search history by file name...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: SwiftBeamColors.primaryCyan),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: SwiftBeamColors.primaryCyan),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
              const SizedBox(height: 12),
              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: HistoryFilter.values.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    final label =
                        filter.name[0].toUpperCase() + filter.name.substring(1);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor:
                            SwiftBeamColors.primaryCyan.withValues(alpha: 0.25),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        side: BorderSide(
                          color: isSelected
                              ? SwiftBeamColors.primaryCyan
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? SwiftBeamColors.primaryCyan
                              : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilter = filter);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredHistory.isEmpty
                    ? Center(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.history_toggle_off_rounded,
                                color: Colors.white38,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                rawHistory.isEmpty
                                    ? 'No Transfers Saved Yet'
                                    : 'No Matching Transfers Found',
                                style: SwiftBeamTypography.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rawHistory.isEmpty
                                    ? 'Files sent or received over SwiftBeam will automatically be saved here.'
                                    : 'Try clearing your search query or choosing a different filter chip.',
                                textAlign: TextAlign.center,
                                style: SwiftBeamTypography.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filteredHistory[index];
                          final isSent =
                              item.direction == TransferDirection.send;
                          final isCompleted =
                              item.status == TransferStatus.completed;

                          final statusColor = isCompleted
                              ? const Color(0xFF00D97E)
                              : const Color(0xFFFF5D73);

                          return InkWell(
                            onTap: () => _showRecordDetails(item),
                            borderRadius: BorderRadius.circular(16),
                            child: GlassContainer(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSent
                                          ? SwiftBeamColors.primaryCyan
                                              .withValues(alpha: 0.15)
                                          : SwiftBeamColors.accentPurple
                                              .withValues(alpha: 0.15),
                                    ),
                                    child: Icon(
                                      isSent
                                          ? Icons.upload_rounded
                                          : Icons.download_rounded,
                                      color: isSent
                                          ? SwiftBeamColors.primaryCyan
                                          : SwiftBeamColors.accentPurple,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.fileName,
                                          style:
                                              SwiftBeamTypography.titleMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              _formatSize(item.fileSize),
                                              style: SwiftBeamTypography
                                                  .bodyMedium
                                                  .copyWith(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                    alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isCompleted
                                                    ? 'SUCCESS'
                                                    : 'FAILED',
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _formatDateTime(item.timestamp),
                                                style: SwiftBeamTypography
                                                    .bodyMedium,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(historyProvider.notifier)
                                          .removeRecord(item.id);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
