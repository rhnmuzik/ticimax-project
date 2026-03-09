// lib/models/order.dart

class Order {
  final int id;
  final String no;
  final String customerName;
  final String status;
  final double total;
  final String date;

  const Order({
    required this.id,
    required this.no,
    required this.customerName,
    required this.status,
    required this.total,
    required this.date,
  });

  factory Order.fromJson(Map<String, dynamic> j) {
    return Order(
      id:           j['SiparisId']     ?? j['id']           ?? 0,
      no:           j['SiparisNo']     ?? j['no']           ?? '—',
      customerName: j['MusteriAdi']    ?? j['customerName'] ?? '—',
      status:       j['Durum']         ?? j['status']       ?? '—',
      total:        (j['ToplamTutar']  ?? j['total']        ?? 0).toDouble(),
      date:         j['SiparisTarihi'] ?? j['date']         ?? '—',
    );
  }
}
