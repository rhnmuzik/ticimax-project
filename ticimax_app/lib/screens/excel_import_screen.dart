// lib/screens/excel_import_screen.dart
// Excel import - Ticimax'ten indirilen dosyayı import et

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  bool _isProcessing = false;

  Future<void> _moveAndImport() async {
    setState(() => _isProcessing = true);

    try {
      // 1. Downloads'dan taşı
      final moveResult = await ApiService().runScript(
        'move-excel-from-downloads',
      );

      if (moveResult['ok'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dosya taşıma hatası: ${moveResult['error']}'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
        return;
      }

      // 2. Import et
      final importResult = await ApiService().runScript('import-site-excel');

      if (mounted) {
        if (importResult['ok'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Excel başarıyla import edildi'),
              backgroundColor: Color(0xFF00C896),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import hatası: ${importResult['error']}'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _copyUrl() {
    Clipboard.setData(
      const ClipboardData(
        text: 'https://www.rhnmuzik.com/Admin/UrunYonetimi.aspx',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL kopyalandı'),
        backgroundColor: Color(0xFF00C896),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Excel Import',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.file_download_outlined,
              size: 64,
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 24),
            const Text(
              'Excel Import',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ticimax\'ten Excel\'i bilgisayarınıza indirin',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 48),
            _buildStep(
              '1',
              'Ticimax Panel\'i Aç',
              'Bilgisayarınızın browser\'ında aşağıdaki URL\'i açın',
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _copyUrl,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'https://www.rhnmuzik.com/Admin/UrunYonetimi.aspx',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 12,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, color: Color(0xFF6C63FF), size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildStep(
              '2',
              'Excel\'i İndirin',
              'Sağ üstteki "Excel\'e Aktar" butonuna basın\nDosya bilgisayarınızın Downloads klasörüne inecek',
            ),
            const SizedBox(height: 32),
            _buildStep(
              '3',
              'Import Et',
              'Aşağıdaki butona basın\nDosya otomatik olarak taşınıp import edilecek',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _moveAndImport,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isProcessing ? 'İşleniyor...' : 'Taşı ve Import Et'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
