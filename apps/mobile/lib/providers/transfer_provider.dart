import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ffi/api.dart';
import '../domain/models/transfer_history.dart';
import 'history_provider.dart';

class TransferProgress {
  final String transferId;
  final String fileName;
  final int totalSize;
  final int bytesTransferred;
  final int speedBps;
  final int etaSeconds;
  final String
      status; // 'started', 'progressing', 'completed', 'failed', 'paused', 'cancelled'
  final String? error;
  final bool isPaused;
  final TransferDirection direction;

  TransferProgress({
    required this.transferId,
    required this.fileName,
    required this.totalSize,
    this.bytesTransferred = 0,
    this.speedBps = 0,
    this.etaSeconds = 0,
    required this.status,
    this.error,
    this.isPaused = false,
    this.direction = TransferDirection.receive,
  });

  double get progress => totalSize > 0 ? bytesTransferred / totalSize : 0.0;

  TransferProgress copyWith({
    int? bytesTransferred,
    int? speedBps,
    int? etaSeconds,
    String? status,
    String? error,
    bool? isPaused,
    TransferDirection? direction,
  }) {
    return TransferProgress(
      transferId: transferId,
      fileName: fileName,
      totalSize: totalSize,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      speedBps: speedBps ?? this.speedBps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      status: status ?? this.status,
      error: error ?? this.error,
      isPaused: isPaused ?? this.isPaused,
      direction: direction ?? this.direction,
    );
  }
}

class DiscoveredPeer {
  final String peerId;
  final String deviceName;
  final String ip;
  final int port;

  DiscoveredPeer({
    required this.peerId,
    required this.deviceName,
    required this.ip,
    required this.port,
  });

  factory DiscoveredPeer.fromJson(Map<String, dynamic> json) {
    String ip = '';
    if (json['ip'] != null && json['ip'].toString().isNotEmpty) {
      ip = json['ip'].toString();
    } else if (json['ip_addresses'] is List) {
      final addrs = json['ip_addresses'] as List;
      for (final addr in addrs) {
        final s = addr.toString();
        if (!s.contains(':') && s != '127.0.0.1') {
          ip = s;
          break;
        }
      }
      if (ip.isEmpty && addrs.isNotEmpty) {
        ip = addrs.first.toString();
      }
    }
    return DiscoveredPeer(
      peerId: json['peer_id'] ?? json['peerId'] ?? '',
      deviceName: json['device_name'] ?? json['deviceName'] ?? 'Unknown Peer',
      ip: ip,
      port: json['port'] ?? 0,
    );
  }
}

// mDNS Discovery Notifier
class PeerDiscoveryNotifier extends StateNotifier<List<DiscoveredPeer>> {
  PeerDiscoveryNotifier() : super([]);
  bool _isBrowsing = false;

  void start() {
    if (_isBrowsing) return;
    _isBrowsing = true;

    try {
      final ffiStream = startDiscovery();
      ffiStream.listen(
        (eventJson) {
          try {
            final Map<String, dynamic> event = jsonDecode(eventJson);
            final type = event['type'];
            if (type == 'PeerFound') {
              final peer = DiscoveredPeer.fromJson(event);
              if (!state.any((p) => p.peerId == peer.peerId)) {
                state = [...state, peer];
              }
            } else if (type == 'PeerLost') {
              final peerId = event['peer_id'] ?? '';
              state = state.where((p) => p.peerId != peerId).toList();
            }
          } catch (e) {
            debugPrint("mDNS parse error: $e");
          }
        },
        onError: (err) {
          debugPrint("mDNS stream error: $err");
        },
      );
    } catch (e) {
      debugPrint("startDiscovery error: $e");
    }
  }

  void stop() {
    _isBrowsing = false;
    state = [];
  }
}

final peerDiscoveryProvider =
    StateNotifierProvider<PeerDiscoveryNotifier, List<DiscoveredPeer>>((ref) {
  return PeerDiscoveryNotifier();
});

// Transfer List Notifier (QUIC and Web transfers progress)
class TransferListNotifier
    extends StateNotifier<Map<String, TransferProgress>> {
  final Ref _ref;
  TransferListNotifier(this._ref) : super({});

  void addTransfer(TransferProgress progress) {
    state = {...state, progress.transferId: progress};
  }

  void updateProgress(
    String transferId,
    int bytesTransferred,
    int speedBps,
    int etaSeconds,
  ) {
    final current = state[transferId];
    if (current != null) {
      state = {
        ...state,
        transferId: current.copyWith(
          bytesTransferred: bytesTransferred,
          speedBps: speedBps,
          etaSeconds: etaSeconds,
          status: 'progressing',
        ),
      };
    }
  }

  void completeTransfer(String transferId) {
    final current = state[transferId];
    if (current != null) {
      final updated = current.copyWith(
        bytesTransferred: current.totalSize,
        speedBps: 0,
        etaSeconds: 0,
        status: 'completed',
      );

      state = {...state, transferId: updated};

      // Automatically save completed transfer to persistent history
      _ref.read(historyProvider.notifier).addRecord(
            TransferHistoryRecord(
              id: transferId,
              fileName: current.fileName,
              fileSize: current.totalSize,
              peerName: 'SwiftBeam P2P Device',
              direction: current.direction,
              status: TransferStatus.completed,
              timestamp: DateTime.now(),
            ),
          );
    }
  }

  void failTransfer(String transferId, String error) {
    final current = state[transferId];
    if (current != null) {
      final updated = current.copyWith(status: 'failed', error: error);

      state = {...state, transferId: updated};

      // Automatically save failed transfer to persistent history
      _ref.read(historyProvider.notifier).addRecord(
            TransferHistoryRecord(
              id: transferId,
              fileName: current.fileName,
              fileSize: current.totalSize,
              peerName: 'SwiftBeam P2P Device',
              direction: current.direction,
              status: TransferStatus.failed,
              timestamp: DateTime.now(),
            ),
          );
    }
  }

  void pauseTransfer(String transferId) {
    final current = state[transferId];
    if (current != null) {
      state = {
        ...state,
        transferId: current.copyWith(status: 'paused', isPaused: true),
      };
    }
  }

  void resumeTransfer(String transferId) {
    final current = state[transferId];
    if (current != null) {
      state = {
        ...state,
        transferId: current.copyWith(status: 'progressing', isPaused: false),
      };
    }
  }

  void cancelTransfer(String transferId) {
    final current = state[transferId];
    if (current != null) {
      state = {...state, transferId: current.copyWith(status: 'cancelled')};
    }
  }

  void retryTransfer(String transferId) {
    final current = state[transferId];
    if (current != null) {
      state = {
        ...state,
        transferId: current.copyWith(
          bytesTransferred: 0,
          status: 'started',
          isPaused: false,
          error: null,
        ),
      };
    }
  }

  void removeTransfer(String transferId) {
    final newState = Map<String, TransferProgress>.from(state);
    newState.remove(transferId);
    state = newState;
  }

  // Handle incoming FFI JSON events
  void handleFfiEventJson(
    String jsonStr, {
    TransferDirection direction = TransferDirection.receive,
  }) {
    try {
      final Map<String, dynamic> event = jsonDecode(jsonStr);
      final type = event['type'];
      final transferId = event['transfer_id'];

      if (type == 'Started') {
        final fileName = event['file_name'] ?? 'Unknown';
        final newState = Map<String, TransferProgress>.from(state);
        // Remove any temporary/optimistic transfer entries for the same file or fallback placeholder
        newState.removeWhere(
          (id, t) =>
              id.startsWith('tx_') &&
              (t.fileName == fileName ||
                  t.fileName == 'Active File Transfer') &&
              t.bytesTransferred == 0,
        );

        newState[transferId] = TransferProgress(
          transferId: transferId,
          fileName: fileName,
          totalSize: (event['total_size'] as num?)?.toInt() ?? 0,
          status: 'started',
          direction: direction,
        );
        state = newState;
      } else if (type == 'Progress') {
        final newState = Map<String, TransferProgress>.from(state);
        final current = newState[transferId];
        final fileName = current?.fileName ?? event['file_name'];
        if (fileName != null) {
          newState.removeWhere(
            (id, t) =>
                id.startsWith('tx_') &&
                (t.fileName == fileName ||
                    t.fileName == 'Active File Transfer') &&
                t.bytesTransferred == 0,
          );
          state = newState;
        }

        updateProgress(
          transferId,
          (event['bytes_transferred'] as num?)?.toInt() ?? 0,
          (event['speed_bps'] as num?)?.toInt() ?? 0,
          (event['eta_seconds'] as num?)?.toInt() ?? 0,
        );
      } else if (type == 'Completed') {
        completeTransfer(transferId);
      } else if (type == 'Failed') {
        failTransfer(transferId, event['error'] ?? 'Unknown Error');
      } else if (type == 'Paused') {
        pauseTransfer(transferId);
      } else if (type == 'Cancelled') {
        cancelTransfer(transferId);
      }
    } catch (e) {
      debugPrint('handleFfiEventJson error: $e');
    }
  }
}

final transferListProvider =
    StateNotifierProvider<TransferListNotifier, Map<String, TransferProgress>>((
  ref,
) {
  return TransferListNotifier(ref);
});
