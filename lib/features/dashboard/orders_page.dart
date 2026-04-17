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
  int? _cancellingOrderId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final orderId = order['id'] as int;
    debugPrint('Cancelling order: $orderId');

    setState(() => _cancellingOrderId = orderId);

    try {
      final itemsResponse = await Supabase.instance.client
          .from('order_items')
          .select('product_id, quantity')
          .eq('order_id', orderId);

      debugPrint('Items response: $itemsResponse');
      final items = itemsResponse as List;
      debugPrint('Found ${items.length} items');

      if (items.isEmpty) {
        debugPrint('No items found, still cancelling order');
      } else {
        for (var item in items) {
          final productId = item['product_id'];
          final quantity = item['quantity'] as int;
          debugPrint('Restoring stock for product $productId, qty: $quantity');

          final productResp = await Supabase.instance.client
              .from('products')
              .select('stock_quantity')
              .eq('id', productId)
              .single();
          final currentStock = productResp['stock_quantity'] ?? 0;
          final newStock = currentStock + quantity;
          debugPrint('Current stock: $currentStock, new stock: $newStock');

          await Supabase.instance.client
              .from('products')
              .update({'stock_quantity': newStock})
              .eq('id', productId);
        }
      }

      debugPrint('Updating order status to cancelled');
      await Supabase.instance.client
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);

      debugPrint('Order cancelled successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled. Stock restored.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrders();
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingOrderId = null);
    }
  }

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
          .eq(
            'customer_name',
            Supabase.instance.client.auth.currentUser?.email ?? '',
          )
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your order history will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _orders
                    .where(
                      (o) =>
                          o['status'].toString().toLowerCase() != 'cancelled',
                    )
                    .length,
                itemBuilder: (context, index) {
                  final activeOrders = _orders
                      .where(
                        (o) =>
                            o['status'].toString().toLowerCase() != 'cancelled',
                      )
                      .toList();
                  final order = activeOrders[index];
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toString().toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(order['created_at']),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: status.toString().toLowerCase() == 'pending'
                          ? _cancellingOrderId == (order['id'] as int)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _showCancelDialog(order),
                                  )
                          : null,
                      children: items.map<Widget>((item) {
                        final product =
                            item['products'] as Map<String, dynamic>?;
                        return ListTile(
                          leading:
                              product?['image_url'] != null &&
                                  (product!['image_url'] as String).isNotEmpty
                              ? Image.network(
                                  product['image_url'],
                                  width: 40,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 40,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image, size: 20),
                                ),
                          title: Text(product?['name'] ?? 'Unknown Product'),
                          subtitle: Text(
                            'Qty: ${item['quantity']} × ₱${item['price_at_time']}',
                          ),
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

  void _showCancelDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          'Are you sure you want to cancel Order #${order['id']}? This will restore the stock quantity.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder(order);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
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
