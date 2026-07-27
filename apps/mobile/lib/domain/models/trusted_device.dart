import 'dart:convert';

class TrustedDevice {
  final String id;
  final String name;
  final String publicKey;
  final DateTime lastConnected;
  final bool autoAccept;

  TrustedDevice({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.lastConnected,
    this.autoAccept = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'publicKey': publicKey,
      'lastConnected': lastConnected.toIso8601String(),
      'autoAccept': autoAccept,
    };
  }

  factory TrustedDevice.fromMap(Map<String, dynamic> map) {
    return TrustedDevice(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      publicKey: map['publicKey'] ?? '',
      lastConnected: DateTime.parse(
          map['lastConnected'] ?? DateTime.now().toIso8601String()),
      autoAccept: map['autoAccept'] ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory TrustedDevice.fromJson(String source) =>
      TrustedDevice.fromMap(jsonDecode(source));
}
