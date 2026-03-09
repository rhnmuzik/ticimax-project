// lib/screens/home_screen.dart
// Dashboard — sunucu durumu + hızlı erişim kartları

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'orders_screen.dart';
import 'stock_screen.dart';
import 'connect_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool? _connected;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final ok = await ApiService().ping();
    if (mounted) setState(() => _connected = ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text('Ticimax', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _checkConnection();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusCard(),
            const SizedBox(height: 20),
            const Text('Hızlı Erişim', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _navCard(
              icon: Icons.shopping_bag_outlined,
              title: 'Siparişler',
              sub: 'Son siparişleri görüntüle',
              color: const Color(0xFF6C63FF),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
            ),
            const SizedBox(height: 12),
            _navCard(
              icon: Icons.inventory_2_outlined,
              title: 'Stok Sorgula',
              sub: 'SKU ile anlık stok sorgula',
              color: const Color(0xFF00C896),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockScreen())),
            ),
            const SizedBox(height: 12),
            _navCard(
              icon: Icons.webhook_outlined,
              title: 'Connect Payloads',
              sub: 'Ticimax Connect eylem logları',
              color: const Color(0xFFFF6B6B),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectScreen())),
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
        border: Border.all(color: dotColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          GestureDetector(
            onTap: () { setState(() => _connected = null); _checkConnection(); },
            child: const Icon(Icons.refresh, color: Colors.white38, size: 20),
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
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
