// lib/screens/orders_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/order.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  int _sayfa = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getOrders(sayfa: _sayfa);
      setState(() { _orders = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Siparişler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _orders.isEmpty
                      ? const Center(child: Text('Sipariş bulunamadı.', style: TextStyle(color: Colors.white54)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _orderCard(_orders[i]),
                        ),
                ),
    );
  }

  Widget _orderCard(Order o) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#${o.no}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              _statusBadge(o.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(o.customerName, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(o.date, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Text('${o.total.toStringAsFixed(2)} ₺', style: const TextStyle(color: Color(0xFF00C896), fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    if (status.toLowerCase().contains('tamamlandi') || status.toLowerCase().contains('teslim')) {
      bg = const Color(0xFF00C896);
    } else if (status.toLowerCase().contains('iptal')) {
      bg = const Color(0xFFFF6B6B);
    } else {
      bg = const Color(0xFF6C63FF);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: bg, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _errorView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _load, child: const Text('Tekrar Dene')),
      ],
    ),
  );
}
