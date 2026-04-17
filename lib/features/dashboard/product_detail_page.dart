import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../model/product_model.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _isLoading = false;
  int _quantity = 1;

  String _getCategoryName(String id) {
    switch (id) {
      case '1': return 'Fruits';
      case '2': return 'Delicacies';
      case '3': return 'Crafts';
      default: return 'General';
    }
  }

  Future<void> _addToCart() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final existing = await Supabase.instance.client
          .from('carts')
          .select('quantity')
          .eq('user_id', userId)
          .eq('product_id', widget.product.id)
          .maybeSingle();
      if (existing != null) {
        await Supabase.instance.client
            .from('carts')
            .update({'quantity': existing['quantity'] + _quantity})
            .eq('user_id', userId)
            .eq('product_id', widget.product.id);
      } else {
        await Supabase.instance.client.from('carts').insert({
          'user_id': userId,
          'product_id': widget.product.id,
          'quantity': _quantity,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(p.name),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero image
                  Stack(
                    children: [
                      Container(
                        height: 260,
                        width: double.infinity,
                        color: Colors.grey[100],
                        child: p.imageUrl.isNotEmpty
                            ? Image.network(p.imageUrl, fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFFE8F5E9),
                                child: Icon(Icons.store,
                                    size: 72, color: Colors.green[300]),
                              ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[800]!.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('In Stock',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),

                  // Name + price
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('per kilogram',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        Text('₱${p.price.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800])),
                      ],
                    ),
                  ),

                  // Description
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Description',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          Text(
                            p.description.isNotEmpty
                                ? p.description
                                : 'No description available.',
                            style: const TextStyle(
                                fontSize: 14, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Store + distance row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Store details',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.storefront_outlined,
                                label: 'Vendor',
                                value: p.vendorName,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.location_on_outlined,
                                label: 'Distance',
                                value: '${p.distance} km away',
                                iconColor: Colors.red[400],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Category tile — full width
                        _InfoTile(
                          icon: Icons.label_outline,
                          label: 'Category',
                          value: _getCategoryName(p.categoryId.toString()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom action bar — safe area aware
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // Quantity stepper
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _StepperButton(
                          icon: Icons.remove,
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          filled: false,
                        ),
                        SizedBox(
                          width: 36,
                          child: Text('$_quantity',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                        _StepperButton(
                          icon: Icons.add,
                          onPressed: () => setState(() => _quantity++),
                          filled: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Add to cart button
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _addToCart,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.shopping_cart_outlined,
                                size: 18),
                        label: Text(
                          _isLoading
                              ? 'Adding...'
                              : 'Add to cart · ₱${(p.price * _quantity).toStringAsFixed(2)}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
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

// Reusable info tile widget
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 16, color: iconColor ?? Colors.green[800]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.visible),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Stepper button (− / +)
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 44,
        decoration: BoxDecoration(
          color: filled ? Colors.green[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: filled
                ? Colors.white
                : onPressed == null
                    ? Colors.grey[400]
                    : Colors.grey[700]),
      ),
    );
  }
}