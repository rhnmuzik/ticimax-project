// lib/screens/excel_export_screen.dart
// Değişen ürünleri Excel olarak oluştur

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class ExcelExportScreen extends StatefulWidget {
  const ExcelExportScreen({super.key});

  @override
  State<ExcelExportScreen> createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends State<ExcelExportScreen> {
  bool _isGenerating = false;
  String? _resultMessage;
  bool? _isSuccess;

  Future<void> _generateChangesExcel() async {
    setState(() {
      _isGenerating = true;
      _resultMessage = null;
      _isSuccess = null;
    });

    try {
      final result = await ApiService().runScript('generate-changes-excel');
      final output = result['output'] as String? ?? '';

      if (output.contains('değişiklik yok')) {
        if (mounted) {
          setState(() {
            _resultMessage = 'Son importtan beri değişiklik yok';
            _isSuccess = null;
          });
        }
        return;
      }

      if (result['ok'] != true) {
        if (mounted) {
          setState(() {
            _resultMessage = result['error'] ?? 'Bilinmeyen hata';
            _isSuccess = false;
          });
        }
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:3099/download-changes-excel'),
      );

      if (response.statusCode != 200) {
        throw Exception('Dosya indirilemedi');
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/ticimax-changes.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        setState(() {
          _resultMessage = 'Excel oluşturuldu\n📍 $filePath';
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultMessage = 'Hata: $e';
          _isSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
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
          'Excel Export',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.file_upload_outlined,
              size: 80,
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 24),
            const Text(
              'Değişiklikleri Ticimax\'e Yükle',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Son importtan beri değişen ürünleri içeren Excel oluşturur',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateChangesExcel,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isGenerating ? 'Oluşturuluyor...' : 'Excel Oluştur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess == null
                      ? const Color(0xFFFFA500).withValues(alpha: 0.1)
                      : _isSuccess!
                      ? const Color(0xFF00C896).withValues(alpha: 0.1)
                      : const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSuccess == null
                        ? const Color(0xFFFFA500).withValues(alpha: 0.3)
                        : _isSuccess!
                        ? const Color(0xFF00C896).withValues(alpha: 0.3)
                        : const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess == null
                          ? Icons.info
                          : _isSuccess!
                          ? Icons.check_circle
                          : Icons.error,
                      color: _isSuccess == null
                          ? const Color(0xFFFFA500)
                          : _isSuccess!
                          ? const Color(0xFF00C896)
                          : const Color(0xFFFF6B6B),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _resultMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF6C63FF),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Bilgi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Excel oluşturulduktan sonra bilgisayarınızdan erişebilirsiniz',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '• Konum: data/ticimax-import/ticimax-changes.xlsx',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '• Ticimax panel\'den "Excel\'den Aktar" ile yükleyin',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
