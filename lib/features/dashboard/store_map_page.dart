import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class StoreFinderPage extends StatefulWidget {
  const StoreFinderPage({super.key});

  @override
  State<StoreFinderPage> createState() => _StoreFinderPageState();
}

class _StoreFinderPageState extends State<StoreFinderPage> {
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;
  LatLng? _userLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission().catchError((_) => LocationPermission.denied);
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().catchError((_) => LocationPermission.denied);
      }

      Position? position;
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        try {
          position = await Geolocator.getCurrentPosition();
        } catch (_) {
          position = null;
        }
      }

final response = await Supabase.instance.client
          .from('vendors')
          .select('id, store_name, latitude, longitude')
          .order('store_name');

      setState(() {
        _vendors = List<Map<String, dynamic>>.from(response as List);
        if (position != null) {
          _userLocation = LatLng(position.latitude, position.longitude);
        }
        _isLoading = false;
      });

      if (_userLocation != null && _vendors.isNotEmpty) {
        _mapController.move(_userLocation!, 13);
      }
    } catch (e) {
      debugPrint('Error loading vendors: $e');
      setState(() => _isLoading = false);
    }
  }

  LatLng get _center {
    if (_userLocation != null) return _userLocation!;
    if (_vendors.isNotEmpty) {
      final v = _vendors.first;
      return LatLng((v['latitude'] as num).toDouble(), (v['longitude'] as num).toDouble());
    }
    return const LatLng(7.0731, 125.6128);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Finder'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_userLocation != null) {
                _mapController.move(_userLocation!, 14);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.davao_msme_hub',
                ),
                MarkerLayer(
                  markers: [
                    if (_userLocation != null)
                      Marker(
                        point: _userLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                      ),
                    ..._vendors.map((vendor) {
                      final lat = (vendor['latitude'] as num).toDouble();
                      final lng = (vendor['longitude'] as num).toDouble();
                      double? distance;
                      if (_userLocation != null) {
                        distance = Geolocator.distanceBetween(
                          _userLocation!.latitude,
                          _userLocation!.longitude,
                          lat,
                          lng,
                        ) / 1000;
                      }
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 120,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => _showVendorInfo(vendor),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      vendor['store_name'] ?? 'Store',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (distance != null)
                                      Text(
                                        '${distance.toStringAsFixed(1)} km',
                                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.location_on, color: Colors.green[700], size: 24),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
    );
  }

  void _showVendorInfo(Map<String, dynamic> vendor) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Colors.green[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vendor['store_name'] ?? 'Store',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Lat: ${vendor['latitude']}, Lng: ${vendor['longitude']}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}