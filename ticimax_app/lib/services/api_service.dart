// lib/services/api_service.dart
// Node.js API server'a tüm HTTP isteklerini yönetir.
// Server URL'i ayarlardan okunur; aynı Wi-Fi'da olmak gerekir.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/connect_payload.dart';

class ApiService {
  // ── Singleton ─────────────────────────────────────────
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  static const _baseKey = 'server_url';
  static const _defaultUrl = 'http://localhost:3099';

  // ── Base URL ──────────────────────────────────────────
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_baseKey) ?? _defaultUrl).trimRight().replaceAll(
      RegExp(r'/+$'),
      '',
    );
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseKey, url.trim());
  }

  // ── HTTP ──────────────────────────────────────────────
  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? params,
  ]) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base$path').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final base = await getBaseUrl();
    final res = await http
        .post(
          Uri.parse('$base$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Health ────────────────────────────────────────────
  Future<bool> ping() async {
    try {
      final res = await _get('/health');
      return res['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Orders ────────────────────────────────────────────
  Future<List<Order>> getOrders({int sayfa = 1, int sayfaBasina = 20}) async {
    final res = await _get('/orders', {
      'sayfa': '$sayfa',
      'sayfaBasina': '$sayfaBasina',
    });
    final raw = res['data'];
    if (raw == null) return [];
    final list = raw is List ? raw : (raw['Liste'] ?? raw['Data'] ?? []);
    return (list as List)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getOrderDetail(int id) async {
    final res = await _get('/orders/$id');
    return (res['data'] ?? {}) as Map<String, dynamic>;
  }

  // ── Products ──────────────────────────────────────────
  Future<List<Product>> getProducts({
    int sayfa = 1,
    int sayfaBasina = 20,
  }) async {
    final res = await _get('/products', {
      'sayfa': '$sayfa',
      'sayfaBasina': '$sayfaBasina',
    });
    final raw = res['data'];
    if (raw == null) return [];
    final list = raw is List ? raw : (raw['Liste'] ?? raw['Data'] ?? []);
    return (list as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Stock ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getStock(String sku) async {
    final res = await _get('/stock/${Uri.encodeComponent(sku)}');
    return (res['data'] ?? {}) as Map<String, dynamic>;
  }

  Future<bool> updateStock(String sku, int miktar) async {
    final res = await _post('/stock/${Uri.encodeComponent(sku)}', {
      'miktar': miktar,
    });
    return res['ok'] == true;
  }

  // ── Connect Payloads ──────────────────────────────────
  Future<List<ConnectPayload>> getConnectPayloads() async {
    final res = await _get('/connect-payloads');
    final data = res['data'] as List? ?? [];
    return data
        .map((e) => ConnectPayload.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Scripts ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getScripts() async {
    final res = await _get('/scripts');
    final scripts = res['scripts'] as List? ?? [];
    return scripts.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> runScript(String name) async {
    final base = await getBaseUrl();
    try {
      final res = await http
          .post(
            Uri.parse('$base/scripts/$name/run'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(minutes: 5));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'ok': data['ok'] ?? false,
        'code': data['code'] ?? -1,
        'output': data['output'] ?? '',
        'error': data['error'],
        'duration': data['duration'] ?? 0,
      };
    } catch (e) {
      return {
        'ok': false,
        'code': -1,
        'output': '',
        'error': 'Network error: $e',
        'duration': 0,
      };
    }
  }

  // ── Last Import Time ──────────────────────────────────
  Future<Map<String, dynamic>> getLastImportTime() async {
    try {
      final res = await _get('/last-import-time');
      return {'ok': res['ok'] ?? false, 'lastImport': res['lastImport']};
    } catch (e) {
      return {'ok': false, 'lastImport': null};
    }
  }
}
