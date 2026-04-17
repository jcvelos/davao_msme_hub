import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../model/product_model.dart';

class CartPage extends StatefulWidget {
  final Map<int, int> cartItems;
  final List<Product> products;
  final VoidCallback onRefresh;

  const CartPage({
    super.key,
    required this.cartItems,
    required this.products,
    required this.onRefresh,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Map<int, int> _localCart;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _localCart = Map.from(widget.cartItems);
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  List<Product> get _cartProducts {
    return widget.products.where((p) => _localCart.containsKey(p.id)).toList();
  }

  double get _totalAmount {
    double total = 0;
    for (var product in _cartProducts) {
      total += product.price * (_localCart[product.id] ?? 0);
    }
    return total;
  }

  int get _totalItems => _localCart.values.fold(0, (a, b) => a + b);

  Future<void> _updateQuantity(int productId, int delta) async {
    final userId = _userId;
    if (userId == null) return;

    final currentQty = _localCart[productId] ?? 0;
    final product = widget.products.firstWhere((p) => p.id == productId);
    final maxQty = product.stock;
    final newQty = currentQty + delta;

    if (newQty <= 0) {
      _removeItem(productId);
      return;
    }

    if (newQty > maxQty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Only ${product.stock} items available in stock'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _localCart[productId] = newQty;
    });

    try {
      await Supabase.instance.client
          .from('carts')
          .update({'quantity': newQty})
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      debugPrint('Error updating quantity: $e');
    }
  }

  Future<void> _removeItem(int productId) async {
    final userId = _userId;
    if (userId == null) return;

    setState(() {
      _localCart.remove(productId);
    });

    try {
      await Supabase.instance.client
          .from('carts')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      debugPrint('Error removing item: $e');
    }
  }

  Future<void> _checkout() async {
    if (_localCart.isEmpty) return;

    for (var entry in _localCart.entries) {
      final product = widget.products.firstWhere((p) => p.id == entry.key);
      if (product.stock < entry.value) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient stock for ${product.name}. Only ${product.stock} available.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);
    final userId = _userId;
    if (userId == null) return;

    try {
      final firstProduct = _cartProducts.first;
      await Supabase.instance.client
          .from('products')
          .select('vendor_id')
          .eq('id', firstProduct.id)
          .single();

      final orderResponse = await Supabase.instance.client
          .from('orders')
          .insert({
            'customer_name':
                Supabase.instance.client.auth.currentUser?.email ?? 'Guest',
            'total_amount': _totalAmount,
            'status': 'pending',
          })
          .select()
          .single();

      final orderId = orderResponse['id'];

      for (var entry in _localCart.entries) {
        final product = widget.products.firstWhere((p) => p.id == entry.key);
        await Supabase.instance.client.from('order_items').insert({
          'order_id': orderId,
          'product_id': entry.key,
          'quantity': entry.value,
          'price_at_time': product.price,
        });
      }

      await Supabase.instance.client
          .from('carts')
          .delete()
          .eq('user_id', userId);

      for (var entry in _localCart.entries) {
        final product = widget.products.firstWhere((p) => p.id == entry.key);
        final newStock = product.stock - entry.value;
        await Supabase.instance.client
            .from('products')
            .update({'stock_quantity': newStock})
            .eq('id', entry.key);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$orderId placed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRefresh();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Checkout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _cartProducts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cartProducts.length,
                    itemBuilder: (context, index) {
                      final product = _cartProducts[index];
                      final qty = _localCart[product.id] ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: product.imageUrl.isNotEmpty
                              ? Image.network(
                                  product.imageUrl,
                                  width: 50,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 50,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₱${product.price}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Subtotal: ₱${(product.price * qty).toStringAsFixed(2)}',
                              ),
                              Text(
                                'Stock: ${product.stock}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: product.stock > 0
                                      ? Colors.grey[600]
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    _updateQuantity(product.id, -1),
                              ),
                              Text(
                                '$qty',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _updateQuantity(product.id, 1),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total (${_totalItems} items)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '���${_totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _checkout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Checkout',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
