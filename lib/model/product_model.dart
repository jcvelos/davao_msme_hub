class Product {
  final int id;
  final String name;
  final String vendorName;
  final String description;
  final double price;
  final String imageUrl;
  final int categoryId;
  final double distance;
  final int stock;

  Product({
    required this.id,
    required this.name,
    required this.vendorName,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.distance = 0.0,
    this.stock = 0,
  });

  factory Product.fromMap(
    Map<String, dynamic> map, {
    double calculatedDistance = 0.0,
  }) {
    final vendorData = map['vendors'] is Map
        ? map['vendors'] as Map<String, dynamic>
        : null;

    return Product(
      id: map['id'] ?? 0,
      name: map['name'] ?? 'Unnamed Product',

      vendorName: vendorData?['store_name']?.toString() ?? 'Unknown Vendor',
      description: map['description'] ?? 'No description provided.',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['image_url'] ?? '',
      categoryId: map['category_id'] ?? 0,
      distance: calculatedDistance,
      stock: map['stock_quantity'] ?? 0,
    );
  }
}
