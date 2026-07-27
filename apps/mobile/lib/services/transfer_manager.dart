import 'dart:async';

class ActiveTransferState {
  final String fileName;
  final double bytesTransferredMB;
  final double totalBytesMB;
  final double currentSpeedMBps;
  final String eta;
  final String encryptionType;
  final String networkType;
  final bool isCompleted;

  ActiveTransferState({
    required this.fileName,
    required this.bytesTransferredMB,
    required this.totalBytesMB,
    required this.currentSpeedMBps,
    required this.eta,
    this.encryptionType = 'ChaCha20-Poly1305 (256-bit)',
    this.networkType = 'QUIC UDP / Wi-Fi Direct',
    this.isCompleted = false,
  });

  double get progressRatio => totalBytesMB > 0
      ? (bytesTransferredMB / totalBytesMB).clamp(0.0, 1.0)
      : 0.0;
  int get progressPercent => (progressRatio * 100).toInt();

  String get formattedTransferred => bytesTransferredMB >= 1024
      ? '${(bytesTransferredMB / 1024).toStringAsFixed(2)} GB'
      : '${bytesTransferredMB.toStringAsFixed(1)} MB';

  String get formattedTotal => totalBytesMB >= 1024
      ? '${(totalBytesMB / 1024).toStringAsFixed(2)} GB'
      : '${totalBytesMB.toStringAsFixed(1)} MB';
}

class TransferManager {
  final _stateController = StreamController<ActiveTransferState>.broadcast();

  Stream<ActiveTransferState> get transferStateStream =>
      _stateController.stream;

  ActiveTransferState getInitialTransferState({
    String fileName = 'Incoming Stream Data',
    double totalMB = 0.0,
  }) {
    return ActiveTransferState(
      fileName: fileName,
      bytesTransferredMB: 0.0,
      totalBytesMB: totalMB,
      currentSpeedMBps: 0.0,
      eta: '--:--',
    );
  }
}
