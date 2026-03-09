// lib/screens/scripts_screen.dart
// Kategorize edilmiş script yönetimi

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ScriptsScreen extends StatefulWidget {
  const ScriptsScreen({super.key});

  @override
  State<ScriptsScreen> createState() => _ScriptsScreenState();
}

class _ScriptsScreenState extends State<ScriptsScreen> {
  late Future<List<Map<String, dynamic>>> _scriptsFuture;
  String? _runningScript;
  Map<String, String> _lastResults = {};

  // Script kategorileri ve açıklamaları
  final Map<String, Map<String, dynamic>> _scriptInfo = {
    // Fiyat Güncellemeleri
    'update-4c-price': {
      'category': 'Fiyat',
      'title': '4C Fiyat Güncelle',
      'icon': Icons.attach_money,
      'color': Color(0xFF6C63FF),
    },
    'update-macom-price': {
      'category': 'Fiyat',
      'title': 'Macom Fiyat Güncelle',
      'icon': Icons.attach_money,
      'color': Color(0xFF6C63FF),
    },
    'update-maske-price': {
      'category': 'Fiyat',
      'title': 'Maske Fiyat Güncelle',
      'icon': Icons.attach_money,
      'color': Color(0xFF6C63FF),
    },

    // Stok İşlemleri
    'update-stock': {
      'category': 'Stok',
      'title': 'Stok Güncelle',
      'icon': Icons.inventory_2,
      'color': Color(0xFF00C896),
    },

    // Excel İşlemleri
    'import-site-excel': {
      'category': 'Excel',
      'title': 'Site Excel Import',
      'icon': Icons.upload_file,
      'color': Color(0xFF00BCD4),
    },
    'generate-changes-excel': {
      'category': 'Excel',
      'title': 'Değişiklik Excel Oluştur',
      'icon': Icons.auto_awesome,
      'color': Color(0xFF00BCD4),
    },
    'update-excel-price': {
      'category': 'Excel',
      'title': 'Excel Fiyat Güncelle',
      'icon': Icons.edit,
      'color': Color(0xFF00BCD4),
    },
    'update-excel-stock': {
      'category': 'Excel',
      'title': 'Excel Stok Güncelle',
      'icon': Icons.edit,
      'color': Color(0xFF00BCD4),
    },

    // XML İşlemleri
    'fetch-xmls': {
      'category': 'XML',
      'title': 'XML İndir',
      'icon': Icons.download,
      'color': Color(0xFFFFA500),
    },

    // E-Ticaret Kontrolleri
    'check-hb-legacy': {
      'category': 'Kontrol',
      'title': 'Hepsiburada Kontrol',
      'icon': Icons.check_circle,
      'color': Color(0xFFFF6B6B),
    },
    'check-n11-legacy': {
      'category': 'Kontrol',
      'title': 'N11 Kontrol',
      'icon': Icons.check_circle,
      'color': Color(0xFFFF6B6B),
    },
    'check-trendyol-legacy': {
      'category': 'Kontrol',
      'title': 'Trendyol Kontrol',
      'icon': Icons.check_circle,
      'color': Color(0xFFFF6B6B),
    },

    // Diğer
    'assign-suppliers': {
      'category': 'Diğer',
      'title': 'Tedarikçi Ata',
      'icon': Icons.business,
      'color': Color(0xFF9C27B0),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadScripts();
  }

  void _loadScripts() {
    setState(() {
      _scriptsFuture = ApiService().getScripts();
    });
  }

  Future<void> _runScript(String name) async {
    setState(() {
      _runningScript = name;
      _lastResults[name] = 'Çalışıyor...';
    });

    try {
      final result = await ApiService().runScript(name);
      if (mounted) {
        final duration = result['duration'] as num? ?? 0;
        final isSuccess = result['ok'] == true;

        String resultText;
        if (isSuccess) {
          resultText = '✅ ${duration.toStringAsFixed(1)}s';
        } else {
          resultText = '❌ Hata';
        }

        setState(() {
          _lastResults[name] = resultText;
          _runningScript = null;
        });

        // Detaylı output göster
        if (!isSuccess || (result['output'] as String? ?? '').isNotEmpty) {
          _showOutputDialog(name, result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResults[name] = '❌ Hata';
          _runningScript = null;
        });
      }
    }
  }

  void _showOutputDialog(String scriptName, Map<String, dynamic> result) {
    final output = result['output'] as String? ?? '';
    final error = result['error'] as String? ?? '';
    final duration = result['duration'] as num? ?? 0;
    final isSuccess = result['ok'] == true;
    final info = _scriptInfo[scriptName];
    final title = info?['title'] ?? scriptName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess
                  ? const Color(0xFF00C896)
                  : const Color(0xFFFF6B6B),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '⏱️  ${duration.toStringAsFixed(2)}s',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (output.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    output,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ],
              if (error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _categorizeScripts(
    List<Map<String, dynamic>> scripts,
  ) {
    final categorized = <String, List<Map<String, dynamic>>>{};

    for (final script in scripts) {
      final name = script['name'] as String;
      final info = _scriptInfo[name];
      final category = info?['category'] ?? 'Diğer';

      if (!categorized.containsKey(category)) {
        categorized[category] = [];
      }
      categorized[category]!.add(script);
    }

    return categorized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Scripts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadScripts,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _scriptsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFFF6B6B),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hata: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final scripts = snapshot.data ?? [];
          if (scripts.isEmpty) {
            return const Center(
              child: Text(
                'Script bulunamadı',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final categorized = _categorizeScripts(scripts);
          final categories = [
            'Fiyat',
            'Stok',
            'Excel',
            'XML',
            'Kontrol',
            'Diğer',
          ];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryScripts = categorized[category] ?? [];

              if (categoryScripts.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...categoryScripts.map((script) {
                    final name = script['name'] as String;
                    final info = _scriptInfo[name];
                    final title = info?['title'] ?? name;
                    final icon = info?['icon'] ?? Icons.code;
                    final color = info?['color'] ?? const Color(0xFF6C63FF);
                    final isRunning = _runningScript == name;
                    final lastResult = _lastResults[name];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRunning
                                ? color.withValues(alpha: 0.5)
                                : Colors.white12,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: lastResult != null
                              ? Text(
                                  lastResult,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                          trailing: isRunning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Color(0xFF6C63FF),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  onPressed: () => _runScript(name),
                                  icon: const Icon(Icons.play_arrow, size: 20),
                                  color: color,
                                  style: IconButton.styleFrom(
                                    backgroundColor: color.withValues(
                                      alpha: 0.1,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
