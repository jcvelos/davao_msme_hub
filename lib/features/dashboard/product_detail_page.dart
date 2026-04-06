import 'package:flutter/material.dart';
import '../../model/product_model.dart';

class ProductDetailPage extends StatelessWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Image.network(
              product.imageUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.broken_image, size: 80, color: Colors.grey)),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price and Name Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        "₱${product.price.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Location Info
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                      Text(
                        " ${product.distance.toStringAsFixed(1)} km away",
                        style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 40),
                  
                  // Description
                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    product.description.isNotEmpty ? product.description : "No description available.",
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // --- Info Cards Section ---
                  const Text("Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoCard(
                        context, 
                        title: "Category", 
                        subtitle: _getCategoryName(product.categoryId.toString()), 
                        icon: Icons.category,
                        color: Colors.blue[50]!,
                        iconColor: Colors.blue[700]!,
                      ),
                      const SizedBox(width: 12),
                      _buildInfoCard(
                        context, 
                        title: "Vendor", 
                        subtitle: product.vendorName,
                        icon: Icons.store,
                        color: Colors.orange[50]!,
                        iconColor: Colors.orange[700]!,
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

  // Helper to build the bottom cards
  Widget _buildInfoCard(BuildContext context, {
    required String title, 
    required String subtitle, 
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(String id) {
    switch (id) {
      case '1': return 'Fruits';
      case '2': return 'Delicacies';
      case '3': return 'Crafts';
      default: return 'General';
    }
  }
}