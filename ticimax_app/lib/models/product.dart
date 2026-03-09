// lib/models/product.dart

class Product {
  final int id;
  final String sku;
  final String name;
  final int stock;
  final double price;

  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.stock,
    required this.price,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    return Product(
      id:    j['UrunId']    ?? j['id']    ?? 0,
      sku:   j['StokKodu'] ?? j['sku']   ?? '—',
      name:  j['UrunAdi']  ?? j['name']  ?? '—',
      stock: j['Stok']     ?? j['stock'] ?? 0,
      price: (j['SatisFiyati'] ?? j['price'] ?? 0).toDouble(),
    );
  }
}
