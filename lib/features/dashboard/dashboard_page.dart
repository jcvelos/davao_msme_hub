import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../model/product_model.dart';
import 'product_detail_page.dart'; // Ensure this import points to the correct file

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Product> _allProducts = [];
  List<String> _favoriteIds = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _loadFavorites();
    await _fetchProducts();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _favoriteIds = prefs.getStringList('favorites') ?? []);
  }

  Future<void> _toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteIds.contains(id) ? _favoriteIds.remove(id) : _favoriteIds.add(id);
    });
    await prefs.setStringList('favorites', _favoriteIds);
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position? userPos;
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        userPos = await Geolocator.getCurrentPosition();
      }

      final response = await Supabase.instance.client
          .from('products')
          .select('*, vendors(store_name, latitude, longitude)')
          .order('name');

      final List<Product> loaded = (response as List).map((map) {
        double dist = 0.0;
        final vendor = map['vendors'];
        if (userPos != null && vendor != null) {
          dist = Geolocator.distanceBetween(
            userPos.latitude,
            userPos.longitude,
            (vendor['latitude'] as num).toDouble(),
            (vendor['longitude'] as num).toDouble(),
          ) / 1000;
        }
        return Product.fromMap(map, calculatedDistance: dist);
      }).toList();

      setState(() {
        _allProducts = loaded;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching products: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Product> get _filteredProducts {
    final query = _searchController.text.toLowerCase();
    return _allProducts.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == 'All' || p.categoryId.toString() == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildCatalogTab(),
            _buildFavoritesTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green[700],
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorites"),
        ],
      ),
    );
  }

  // ... (Keep your _buildCatalogTab, _buildFavoritesTab, _buildHeader, etc.) ...
  
  Widget _buildCatalogTab() {
    return RefreshIndicator(
      onRefresh: _fetchProducts,
      color: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildCategoryFilters(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _buildProductGrid(_filteredProducts),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    final favs = _allProducts.where((p) => _favoriteIds.contains(p.id.toString())).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text("My Favorites", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: favs.isEmpty
              ? const Center(child: Text("No favorites yet! ❤️"))
              : _buildProductGrid(favs),
        ),
      ],
    );
  }

Widget _buildHeader() {
  final user = Supabase.instance.client.auth.currentUser;
  final email = user?.email 
      ?? user?.userMetadata?['email'] as String? 
      ?? 'Guest';

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Davao MSME Hub",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[900])),
        Text("Find the best local pasalubong",
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.account_circle, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              "Logged in as $email",
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: "Search Durian, Inabel...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final categories = {'All': 'All', '1': 'Fruits', '2': 'Delicacies', '3': 'Crafts'};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: categories.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: _selectedCategory == entry.key,
              onSelected: (val) => setState(() => _selectedCategory = entry.key),
              selectedColor: Colors.green[100],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    if (products.isEmpty) return const Center(child: Text("No items found"));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          isFavorite: _favoriteIds.contains(product.id.toString()),
          onFavoriteTap: () => _toggleFavorite(product.id.toString()),
        );
      },
    );
  }
}

// Keep ProductCard here as a private helper widget for the dashboard
class ProductCard extends StatelessWidget {
  final Product product;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: product))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Image.network(product.imageUrl, fit: BoxFit.cover, width: double.infinity),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                      Text("₱${product.price}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Colors.grey),
                          Text(" ${product.distance.toStringAsFixed(1)}km", style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 5,
              right: 5,
              child: IconButton(
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                onPressed: onFavoriteTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}