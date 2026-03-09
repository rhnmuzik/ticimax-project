// lib/services/workflow_service.dart
// Workflow'ları yönetme ve çalıştırma servisi

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workflow.dart';
import 'api_service.dart';

class WorkflowService {
  static final WorkflowService _instance = WorkflowService._();
  factory WorkflowService() => _instance;
  WorkflowService._();

  static const _workflowsKey = 'workflows';

  // Workflow'ları kaydet
  Future<void> saveWorkflows(List<Workflow> workflows) async {
    final prefs = await SharedPreferences.getInstance();
    final json = workflows.map((w) => w.toJson()).toList();
    await prefs.setString(_workflowsKey, jsonEncode(json));
  }

  // Workflow'ları yükle
  Future<List<Workflow>> loadWorkflows() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_workflowsKey);
    if (jsonStr == null) return _getDefaultWorkflows();

    try {
      final List<dynamic> json = jsonDecode(jsonStr);
      return json
          .map((e) => Workflow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return _getDefaultWorkflows();
    }
  }

  // Varsayılan workflow'lar
  List<Workflow> _getDefaultWorkflows() => [
    Workflow(
      id: 'daily-sync',
      name: 'Günlük Senkronizasyon',
      description:
          'Site Excel import → XML çek → Tedarikçi ata → Fiyat/Stok güncelle → Değişiklik Excel oluştur',
      scripts: [
        'import-site-excel',
        'fetch-xmls',
        'assign-suppliers',
        'update-4c-price',
        'update-macom-price',
        'update-maske-price',
        'update-stock',
        'generate-changes-excel',
      ],
      schedule: '09:00',
    ),
    Workflow(
      id: 'price-update',
      name: 'Fiyat Güncelleme',
      description: 'Tüm tedarikçi fiyatlarını güncelle',
      scripts: ['update-4c-price', 'update-macom-price', 'update-maske-price'],
    ),
    Workflow(
      id: 'stock-sync',
      name: 'Stok Senkronizasyonu',
      description: 'Stok bilgilerini güncelle',
      scripts: ['update-stock'],
    ),
  ];

  // Workflow çalıştır
  Future<Map<String, dynamic>> runWorkflow(Workflow workflow) async {
    final results = <String, dynamic>{};
    bool allSuccess = true;

    for (final scriptName in workflow.scripts) {
      try {
        final result = await ApiService().runScript(scriptName);
        results[scriptName] = result;

        if (result['ok'] != true) {
          allSuccess = false;
          break; // Hata varsa dur
        }
      } catch (e) {
        results[scriptName] = {'ok': false, 'error': e.toString()};
        allSuccess = false;
        break;
      }
    }

    return {
      'ok': allSuccess,
      'results': results,
      'completedAt': DateTime.now().toIso8601String(),
    };
  }

  // Workflow güncelle
  Future<void> updateWorkflow(Workflow workflow) async {
    final workflows = await loadWorkflows();
    final index = workflows.indexWhere((w) => w.id == workflow.id);

    if (index != -1) {
      workflows[index] = workflow;
    } else {
      workflows.add(workflow);
    }

    await saveWorkflows(workflows);
  }

  // Workflow sil
  Future<void> deleteWorkflow(String id) async {
    final workflows = await loadWorkflows();
    workflows.removeWhere((w) => w.id == id);
    await saveWorkflows(workflows);
  }
}
