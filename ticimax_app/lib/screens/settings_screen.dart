// lib/screens/settings_screen.dart
// Sunucu URL'ini kaydetmek için basit ayarlar ekranı

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ctrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    ApiService().getBaseUrl().then((url) {
      _ctrl.text = url;
    });
  }

  Future<void> _save() async {
    await ApiService().setBaseUrl(_ctrl.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Ayarlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sunucu URL', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'http://192.168.1.x:3099',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1A1D2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.dns_outlined, color: Colors.white38),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Telefonun bilgisayarla aynı Wi-Fi\'da olduğundan emin ol.\nBilgisayarın IP\'sini öğrenmek için: System Settings → Wi-Fi → Details',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved ? const Color(0xFF00C896) : const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_saved ? '✓ Kaydedildi' : 'Kaydet', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
