// lib/models/connect_payload.dart

class ConnectPayload {
  final String file;
  final String action;
  final DateTime receivedAt;
  final Map<String, dynamic> raw;

  const ConnectPayload({
    required this.file,
    required this.action,
    required this.receivedAt,
    required this.raw,
  });

  factory ConnectPayload.fromJson(Map<String, dynamic> j) {
    final fname = j['file'] as String? ?? '';
    // dosya adından timestamp çek: "OrderCreated_1741540800000.json"
    final parts  = fname.replaceAll('.json', '').split('_');
    final tsMs   = int.tryParse(parts.last) ?? 0;
    final action = parts.take(parts.length - 1).join('_');

    return ConnectPayload(
      file:       fname,
      action:     action.isEmpty ? 'unknown' : action,
      receivedAt: tsMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(tsMs)
          : DateTime.now(),
      raw:        Map<String, dynamic>.from(j['payload'] ?? {}),
    );
  }
}
