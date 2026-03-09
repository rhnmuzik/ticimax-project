// lib/screens/discover_screen.dart
// XML'de olup sistemde olmayan yeni ürünleri keşfet

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];
  String? _selectedSupplier;
  String? _selectedCategory;
  Set<String> _selectedSkus = {};

  @override
  void initState() {
    super.initState();
    _loadNewProducts();
  }

  Future<void> _loadNewProducts() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService().getNewProducts();
      print('Discover API response: $response');

      if (mounted) {
        if (response['ok'] == true) {
          final products = response['products'] as List? ?? [];
          print('Loaded ${products.length} new products');
          setState(() {
            _products = List<Map<String, dynamic>>.from(products);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'API hatası: ${response['error'] ?? "Bilinmeyen hata"}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Discover error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var filtered = _products;

    if (_selectedSupplier != null) {
      filtered = filtered
          .where((p) => p['supplier'] == _selectedSupplier)
          .toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where(
            (p) =>
                (p['category'] as String?)?.contains(_selectedCategory!) ??
                false,
          )
          .toList();
    }

    return filtered;
  }

  List<String> get _suppliers {
    return _products.map((p) => p['supplier'] as String).toSet().toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Yeni Ürünler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          if (_selectedSkus.isNotEmpty)
            TextButton.icon(
              onPressed: _addSelectedProducts,
              icon: const Icon(Icons.add, color: Color(0xFF00C896)),
              label: Text(
                '${_selectedSkus.length} Ekle',
                style: const TextStyle(color: Color(0xFF00C896)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Yeni ürün bulunamadı',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final sku = product['sku'] as String;
                            final isSelected = _selectedSkus.contains(sku);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildProductCard(product, isSelected),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D2E),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Filtrele',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_selectedSupplier != null || _selectedCategory != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedSupplier = null;
                      _selectedCategory = null;
                    });
                  },
                  child: const Text('Temizle'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._suppliers.map(
                (s) => _buildFilterChip(
                  label: s.toUpperCase(),
                  isSelected: _selectedSupplier == s,
                  onTap: () {
                    setState(() {
                      _selectedSupplier = _selectedSupplier == s ? null : s;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00C896).withValues(alpha: 0.2)
              : Colors.white12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C896) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00C896) : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isSelected) {
    final sku = product['sku'] as String;
    final name = product['name'] as String? ?? '';
    final supplier = product['supplier'] as String;
    final price = product['price'];
    final stock = product['stock'];
    final currency = product['currency'] as String? ?? 'TRY';

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedSkus.remove(sku);
          } else {
            _selectedSkus.add(sku);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C896) : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedSkus.add(sku);
                  } else {
                    _selectedSkus.remove(sku);
                  }
                });
              },
              activeColor: const Color(0xFF00C896),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sku,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          supplier.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$price $currency',
                        style: const TextStyle(
                          color: Color(0xFF00C896),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Stok: $stock',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSelectedProducts() async {
    if (_selectedSkus.isEmpty) return;

    // Onay dialogu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Ürünleri Ekle',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${_selectedSkus.length} ürün için Excel dosyası oluşturulacak. Devam edilsin mi?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ekle',
              style: TextStyle(color: Color(0xFF00C896)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService().addNewProducts(
        _selectedSkus.toList(),
      );

      if (mounted) {
        if (response['ok'] == true) {
          final filename = response['filename'] as String?;

          if (filename != null) {
            // Excel'i indir
            try {
              final filePath = await ApiService().downloadNewProductsExcel(
                filename,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${response['count']} ürün eklendi\nDosya: $filePath',
                    ),
                    backgroundColor: const Color(0xFF00C896),
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Excel oluşturuldu ama indirilemedi: $e'),
                    backgroundColor: const Color(0xFFFFA500),
                  ),
                );
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${response['count']} ürün başarıyla eklendi'),
                backgroundColor: const Color(0xFF00C896),
              ),
            );
          }

          // Seçimi temizle ve listeyi yenile
          setState(() {
            _selectedSkus.clear();
          });
          await _loadNewProducts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${response['error'] ?? "Bilinmeyen hata"}'),
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
        setState(() => _isLoading = false);
      }
    }
  }
}
