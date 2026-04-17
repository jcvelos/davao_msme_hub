import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _loadOrders() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final ordersResponse = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*, products(name, image_url))')
          .eq('customer_name', Supabase.instance.client.auth.currentUser?.email ?? '')
          .order('created_at', ascending: false);

      setState(() {
        _orders = (ordersResponse as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _orders.isEmpty
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No orders yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Your order history will appear here', style: TextStyle(color: Colors.grey)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final items = order['order_items'] as List? ?? [];
                          final status = order['status'] ?? 'unknown';
                          final statusColor = _getStatusColor(status);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              leading: Icon(Icons.receipt, color: statusColor),
                              title: Text(
                                'Order #${order['id']}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total: ₱${order['total_amount']}'),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status.toString().toUpperCase(),
                                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(order['created_at']),
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              children: items.map<Widget>((item) {
                                final product = item['products'] as Map<String, dynamic>?;
                                return ListTile(
                                  leading: product?['image_url'] != null && (product!['image_url'] as String).isNotEmpty
                                      ? Image.network(product['image_url'], width: 40, fit: BoxFit.cover)
                                      : Container(width: 40, color: Colors.grey[300], child: const Icon(Icons.image, size: 20)),
                                  title: Text(product?['name'] ?? 'Unknown Product'),
                                  subtitle: Text('Qty: ${item['quantity']} × ₱${item['price_at_time']}'),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toString().toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return date.toString();
    }
  }
}