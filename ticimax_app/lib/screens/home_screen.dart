// lib/screens/home_screen.dart
// Dashboard — sunucu durumu + hızlı erişim kartları

import 'package:flutter/material.dart';
import 'package:ticimax_app/screens/ticimax_login_screen.dart';
import 'package:ticimax_app/services/ticimax_service.dart';
import '../services/api_service.dart';
import 'settings_screen.dart';
import 'scripts_screen.dart';
import 'workflows_screen.dart';
import 'excel_import_screen.dart';
import 'excel_export_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool? _connected;
  String? _lastImportTime;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _loadLastImportTime();
  }

  Future<void> _checkConnection() async {
    final ok = await ApiService().ping();
    if (mounted) setState(() => _connected = ok);
  }

  Future<void> _loadLastImportTime() async {
    try {
      final result = await ApiService().getLastImportTime();
      if (mounted && result['ok'] == true) {
        setState(() => _lastImportTime = result['lastImport']);
      }
    } catch (e) {
      // Sessizce hata yut
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_checkConnection(), _loadLastImportTime()]);
  }

  Future<void> _handleExcelImport() async {
    // Önce giriş kontrolü
    final isLoggedIn = await TicimaxService().isLoggedIn();

    if (!isLoggedIn) {
      // Giriş ekranına yönlendir
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TicimaxLoginScreen()),
      );

      if (result != true) return;
    }

    // Excel export işlemi
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final exportResult = await TicimaxService().exportExcel();

      if (mounted) {
        Navigator.pop(context); // Loading dialog'u kapat

        if (exportResult['ok'] == true) {
          // Başarılı - TODO: Dosyayı sunucuya yükle ve import et
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel başarıyla indirildi'),
              backgroundColor: Color(0xFF00C896),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(exportResult['error'] ?? 'Export başarısız'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Ticimax',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _checkConnection();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusCard(),
            const SizedBox(height: 12),
            _lastImportCard(),
            const SizedBox(height: 20),
            const Text(
              'Hızlı Erişim',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _navCard(
              icon: Icons.terminal_outlined,
              title: 'Scripts',
              sub: 'Node.js scriptlerini çalıştır',
              color: const Color(0xFFFFA500),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScriptsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _navCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Workflows',
              sub: 'Otomatik görevler ve senkronizasyon',
              color: const Color(0xFF9C27B0),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkflowsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _navCard(
              icon: Icons.file_download_outlined,
              title: 'Excel Import',
              sub: 'Ticimax\'ten Excel indir ve import et',
              color: const Color(0xFF00BCD4),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExcelImportScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _navCard(
              icon: Icons.file_upload_outlined,
              title: 'Excel Export',
              sub: 'Değişen ürünleri Ticimax\'e yükle',
              color: const Color(0xFFE91E63),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExcelExportScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    Color dotColor;
    String label;
    if (_connected == null) {
      dotColor = Colors.orange;
      label = 'Bağlantı kontrol ediliyor…';
    } else if (_connected!) {
      dotColor = const Color(0xFF00C896);
      label = 'Sunucu bağlı';
    } else {
      dotColor = const Color(0xFFFF6B6B);
      label = 'Sunucuya ulaşılamıyor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dotColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          GestureDetector(
            onTap: _refresh,
            child: const Icon(Icons.refresh, color: Colors.white38, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _lastImportCard() {
    String displayText;
    String timeAgo = '';

    if (_lastImportTime == null) {
      displayText = 'Henüz import yapılmadı';
    } else {
      displayText = 'Son import';
      try {
        final importDate = DateTime.parse(_lastImportTime!);
        final now = DateTime.now();
        final difference = now.difference(importDate);

        if (difference.inMinutes < 1) {
          timeAgo = 'Az önce';
        } else if (difference.inHours < 1) {
          timeAgo = '${difference.inMinutes} dakika önce';
        } else if (difference.inDays < 1) {
          timeAgo = '${difference.inHours} saat önce';
        } else {
          timeAgo = '${difference.inDays} gün önce';
        }
      } catch (e) {
        timeAgo = _lastImportTime!;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.history,
              color: Color(0xFF00BCD4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (timeAgo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      color: Color(0xFF00BCD4),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navCard({
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
