import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../model/product_model.dart';
import 'product_detail_page.dart';
import 'account_page.dart';
import 'cart_page.dart';
import 'orders_page.dart';
import 'store_map_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Product> _allProducts = [];
  List<int> _favoriteIds = [];
  Map<int, int> _cartItems = {};
  bool _isLoading = true;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _initialLoad() async {
    _fetchProducts();
    if (_userId != null) {
      _loadFavorites();
      _loadCart();
    }
  }

  Future<void> _loadFavorites() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _favoriteIds = []);
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('favorites')
          .select('product_id')
          .eq('user_id', userId);
      if (!mounted) return;
      setState(() {
        _favoriteIds = (response as List).map((e) => e['product_id'] as int).toList();
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String productId) async {
    final userId = _userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save favorites')),
      );
      return;
    }

    final pid = int.parse(productId);
    setState(() {
      if (_favoriteIds.contains(pid)) {
        _favoriteIds.remove(pid);
      } else {
        _favoriteIds.add(pid);
      }
    });

    try {
      if (_favoriteIds.contains(pid)) {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': userId,
          'product_id': pid,
        });
      } else {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', pid);
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      await _loadFavorites();
    }
  }

  Future<void> _loadCart() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _cartItems = {});
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('carts')
          .select('product_id, quantity')
          .eq('user_id', userId);
      if (!mounted) return;
      setState(() {
        _cartItems = {for (var e in response) e['product_id'] as int: e['quantity'] as int};
      });
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> _addToCart(Product product) async {
    final userId = _userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add to cart')),
      );
      return;
    }

    final pid = product.id;
    final currentQty = _cartItems[pid] ?? 0;

    setState(() {
      _cartItems[pid] = currentQty + 1;
    });

    try {
      if (currentQty == 0) {
        await Supabase.instance.client.from('carts').insert({
          'user_id': userId,
          'product_id': pid,
          'quantity': 1,
        });
      } else {
        await Supabase.instance.client
            .from('carts')
            .update({'quantity': currentQty + 1})
            .eq('user_id', userId)
            .eq('product_id', pid);
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      await _loadCart();
    }
  }

  int get _cartCount => _cartItems.values.fold(0, (a, b) => a + b);

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission().catchError((_) => LocationPermission.denied);
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().catchError((_) => LocationPermission.denied);
      }

      Position? userPos;
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        try {
          userPos = await Geolocator.getCurrentPosition();
        } catch (_) {
          userPos = null;
        }
      }

      final response = await Supabase.instance.client
          .from('products')
          .select('*, vendors(store_name, latitude, longitude)')
          .order('name');

      final List<Product> loaded = (response as List).map((map) {
        double dist = 0.0;
        final vendor = map['vendors'];
        if (userPos != null && vendor != null) {
          try {
            dist = Geolocator.distanceBetween(
              userPos.latitude,
              userPos.longitude,
              (vendor['latitude'] as num).toDouble(),
              (vendor['longitude'] as num).toDouble(),
            ) / 1000;
          } catch (_) {
            dist = 0.0;
          }
        }
        return Product.fromMap(map, calculatedDistance: dist);
      }).toList();

      if (!mounted) return;
      setState(() {
        _allProducts = loaded;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Product> get _filteredProducts {
    final query = _searchController.text.toLowerCase();
    return _allProducts.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(query) || p.vendorName.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == 'All' || p.categoryId.toString() == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildCatalogTab(),
            _buildFavoritesTab(),
            const OrdersPage(),
            const StoreFinderPage(),
            const AccountPage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green[700],
        showUnselectedLabels: true,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Favorites",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: "Orders",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "Map",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: "Account",
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildCategoryFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _initialLoad,
              color: Colors.green,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : _buildProductGrid(_filteredProducts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    final favs = _allProducts.where((p) => _favoriteIds.contains(p.id)).toList();
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Davao MSME Hub",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[900])),
              Text("Find local Pasalubong",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(
                email,
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CartPage(cartItems: _cartItems, products: _allProducts, onRefresh: _loadCart)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart, size: 28, color: Colors.green),
                if (_cartCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '$_cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
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
          hintText: "Search product or vendor...",
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
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          isFavorite: _favoriteIds.contains(product.id),
          cartQty: _cartItems[product.id] ?? 0,
          onFavoriteTap: () => _toggleFavorite(product.id.toString()),
          onAddToCart: () => _addToCart(product),
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final bool isFavorite;
  final int cartQty;
  final VoidCallback onFavoriteTap;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.cartQty,
    required this.onFavoriteTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final hasInCart = cartQty > 0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
      ),
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(product.imageUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[100],
                            child: Icon(Icons.storefront, size: 36, color: Colors.grey[400]),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: Colors.red[600],
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info section
           Expanded(
  flex: 2,
  child: Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6), // reduced padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // distribute space evenly
      children: [
        // Product name
        Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Vendor name — muted
        Text(
          product.vendorName,
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Price
        Text(
          '₱${product.price.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.green[800],
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        // Add to cart button
        SizedBox(
          width: double.infinity,
          height: 24,
          child: ElevatedButton.icon(
            onPressed: onAddToCart,
            icon: const Icon(Icons.add_shopping_cart, size: 10),
            label: Text(
              hasInCart ? 'In ($cartQty)' : 'Add',
              style: const TextStyle(fontSize: 9),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasInCart ? Colors.grey[700] : Colors.green[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              elevation: 0,
              minimumSize: Size.zero,
            ),
          ),
        ),
      ],
    ),
  ),
),
          ],
        ),
      ),
    );
  }
}