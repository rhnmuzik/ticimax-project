// lib/screens/connect_screen.dart
// Ticimax Connect eylem loglarını görüntüler

import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/connect_payload.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  List<ConnectPayload> _payloads = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getConnectPayloads();
      setState(() { _payloads = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showDetail(ConnectPayload p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(child: Text(p.action, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))),
                const Icon(Icons.close, color: Colors.white38),
              ],
            ),
            const SizedBox(height: 6),
            Text(_fmt(p.receivedAt), style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF0F1117), borderRadius: BorderRadius.circular(12)),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(p.raw),
                style: const TextStyle(color: Color(0xFF00C896), fontFamily: 'monospace', fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year} '
           '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Connect Payloads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white54)))
              : _payloads.isEmpty
                  ? _emptyView()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payloads.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = _payloads[i];
                        return GestureDetector(
                          onTap: () => _showDetail(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B6B).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.webhook, color: Color(0xFFFF6B6B), size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p.action, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(_fmt(p.receivedAt), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                  ]),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white24),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _emptyView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.webhook_outlined, color: Colors.white24, size: 56),
        const SizedBox(height: 12),
        const Text('Henüz payload yok.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        const Text('Ticimax Connect\'te endpoint olarak\nhttp://<ip>:3099/connect-webhook gir.',
            style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
      ],
    ),
  );
}
