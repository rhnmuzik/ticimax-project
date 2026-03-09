// lib/services/ticimax_service.dart
// Ticimax panel'e giriş ve Excel export servisi

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TicimaxService {
  static final TicimaxService _instance = TicimaxService._();
  factory TicimaxService() => _instance;
  TicimaxService._();

  static const _tokenKey = 'ticimax_token';
  static const _cookiesKey = 'ticimax_cookies';
  static const _storeUrlKey = 'ticimax_store_url';

  String? _token;
  String? _cookies;
  String? _storeUrl;

  // Token'ı kaydet
  Future<void> saveToken(String token, String cookies, String storeUrl) async {
    _token = token;
    _cookies = cookies;
    _storeUrl = storeUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_cookiesKey, cookies);
    await prefs.setString(_storeUrlKey, storeUrl);
  }

  // Token'ı yükle
  Future<bool> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _cookies = prefs.getString(_cookiesKey);
    _storeUrl = prefs.getString(_storeUrlKey);

    return _token != null && _cookies != null && _storeUrl != null;
  }

  // Token'ı temizle
  Future<void> clearToken() async {
    _token = null;
    _cookies = null;
    _storeUrl = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_cookiesKey);
    await prefs.remove(_storeUrlKey);
  }

  // Ticimax'e giriş yap
  Future<Map<String, dynamic>> login(
    String storeUrl,
    String username,
    String password,
  ) async {
    try {
      // Ticimax login endpoint'i
      final loginUrl = '$storeUrl/UyeGiris/Login';

      final payload = {
        'Username': username,
        'Password': password,
        'NotMember': 0,
        'Otp': '',
        'SmsCode': '',
        'IsAdmin': false,
        'ReturnUrl': '/UyeGiris?farkliHesap=1',
        'XID': '',
      };

      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      // Cookie'leri al
      final cookies = response.headers['set-cookie'] ?? '';

      if (response.statusCode == 200) {
        // Response body'yi kontrol et
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        // Başarılı giriş kontrolü
        if (responseData['Success'] == true ||
            responseData['success'] == true ||
            cookies.isNotEmpty) {
          // Token'ı bul
          String? token;

          if (cookies.isNotEmpty) {
            final cookieParts = cookies.split(';');
            for (final part in cookieParts) {
              final trimmed = part.trim();
              if (trimmed.startsWith('ASP.NET_SessionId=') ||
                  trimmed.startsWith('.ASPXAUTH=') ||
                  trimmed.startsWith('TicimaxAuth=')) {
                token = trimmed.split('=')[1];
                break;
              }
            }
          }

          // Token bulunamazsa cookie'nin tamamını kullan
          token ??= cookies;

          await saveToken(token, cookies, storeUrl);
          return {'ok': true, 'message': 'Giriş başarılı'};
        } else {
          return {
            'ok': false,
            'error':
                responseData['Message'] ??
                responseData['message'] ??
                'Kullanıcı adı veya şifre hatalı',
          };
        }
      } else {
        return {
          'ok': false,
          'error': 'Giriş başarısız: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'ok': false, 'error': 'Bağlantı hatası: $e'};
    }
  }

  // Excel export
  Future<Map<String, dynamic>> exportExcel() async {
    if (_token == null || _cookies == null || _storeUrl == null) {
      return {'ok': false, 'error': 'Önce giriş yapmalısınız'};
    }

    try {
      // Ticimax Excel export endpoint'i (gerçek endpoint'i öğrenmemiz gerekiyor)
      final exportUrl = '$_storeUrl/Yonetim/Urunler/ExportExcel';

      final response = await http.get(
        Uri.parse(exportUrl),
        headers: {'Cookie': _cookies!},
      );

      if (response.statusCode == 200) {
        return {
          'ok': true,
          'data': response.bodyBytes,
          'filename': 'site_products.xlsx',
        };
      } else {
        return {
          'ok': false,
          'error': 'Export başarısız: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'ok': false, 'error': 'Export hatası: $e'};
    }
  }

  // Session kontrolü
  Future<bool> isLoggedIn() async {
    if (_token == null) {
      await loadToken();
    }
    return _token != null;
  }
}
