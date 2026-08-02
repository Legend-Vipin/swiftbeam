import 'dart:convert';

enum TransferDirection { send, receive }

enum TransferStatus { completed, failed, cancelled }

class TransferHistoryRecord {
  final String id;
  final String fileName;
  final int fileSize;
  final String peerName;
  final TransferDirection direction;
  final TransferStatus status;
  final DateTime timestamp;

  TransferHistoryRecord({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.peerName,
    required this.direction,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileSize': fileSize,
      'peerName': peerName,
      'direction': direction.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TransferHistoryRecord.fromMap(Map<String, dynamic> map) {
    return TransferHistoryRecord(
      id: map['id'] ?? '',
      fileName: map['fileName'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      peerName: map['peerName'] ?? 'Unknown Peer',
      direction: TransferDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => TransferDirection.receive,
      ),
      status: TransferStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransferStatus.completed,
      ),
      timestamp: DateTime.parse(
        map['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory TransferHistoryRecord.fromJson(String source) =>
      TransferHistoryRecord.fromMap(jsonDecode(source));
}
