// lib/widgets/map_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../theme/app_colors.dart';

class MapWidget extends StatefulWidget {
  final double height;
  final bool showUserLocation;

  const MapWidget({
    super.key,
    this.height = 180.0,
    this.showUserLocation = true,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

// Custom painter for grid pattern on the map placeholder
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw horizontal lines
    double horizontalSpacing = size.height / 12;
    for (int i = 0; i < 12; i++) {
      double y = i * horizontalSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical lines
    double verticalSpacing = size.width / 12;
    for (int i = 0; i < 12; i++) {
      double x = i * verticalSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw some circles for a more map-like feel
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.2),
      size.width * 0.1,
      circlePaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.6),
      size.width * 0.15,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _MapWidgetState extends State<MapWidget>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  late AnimationController _animationController;

  // Default to Sudan's central coordinates
  static const LatLng _defaultLocation = LatLng(
    15.5007,
    32.5599,
  ); // Khartoum, Sudan
  LatLng _currentPosition = _defaultLocation;

  final Set<Marker> _markers = {};
  final Location _locationService = Location();
  bool _serviceEnabled = false;
  PermissionStatus _permissionGranted = PermissionStatus.denied;
  LocationData? _locationData;
  bool _isLoading = true;

  // Map style for customized look
  static const String _mapStyle = '''
  [
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        { "color": "#e9e9e9" },
        { "lightness": 17 }
      ]
    },
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [
        { "color": "#f5f5f5" },
        { "lightness": 20 }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#ffffff" },
        { "lightness": 17 }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        { "color": "#ffffff" },
        { "lightness": 29 },
        { "weight": 0.2 }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry",
      "stylers": [
        { "color": "#ffffff" },
        { "lightness": 18 }
      ]
    },
    {
      "featureType": "road.local",
      "elementType": "geometry",
      "stylers": [
        { "color": "#ffffff" },
        { "lightness": 16 }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [
        { "color": "#f5f5f5" },
        { "lightness": 21 }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        { "color": "#dedede" },
        { "lightness": 21 }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        { "visibility": "on" },
        { "color": "#ffffff" },
        { "lightness": 16 }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        { "saturation": 36 },
        { "color": "#333333" },
        { "lightness": 40 }
      ]
    },
    {
      "elementType": "labels.icon",
      "stylers": [
        { "visibility": "off" }
      ]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#fefefe" },
        { "lightness": 20 }
      ]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry.stroke",
      "stylers": [
        { "color": "#fefefe" },
        { "lightness": 17 },
        { "weight": 1.2 }
      ]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for UI effects
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.showUserLocation) {
      _initLocation();
    } else {
      setState(() {
        _isLoading = false;
      });
    }

    // Add a marker for Sudan's capital with custom styling
    _markers.add(
      const Marker(
        markerId: MarkerId('khartoum'),
        position: _defaultLocation,
        infoWindow: InfoWindow(title: 'Khartoum', snippet: 'Capital of Sudan'),
      ),
    );
  }

  // Apply custom style to Google Maps
  Future<void> _applyMapStyle(GoogleMapController controller) async {
    try {
      await controller.setMapStyle(_mapStyle);
    } catch (e) {
      print('Error applying map style: $e');
    }
  }

  // Build a decorative location pin for the web placeholder
  Widget _buildLocationPin(Color color, double size) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -2 * _animationController.value),
          child: Column(
            children: [
              Icon(Icons.location_on, color: color, size: size),
              Container(
                width: size * 0.5,
                height: size * 0.5,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: size * 0.75,
                      spreadRadius: size * 0.25,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Initialize location services and get user's current location
  Future<void> _initLocation() async {
    // Check if location services are enabled
    _serviceEnabled = await _locationService.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locationService.requestService();
      if (!_serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // Check for permission
    _permissionGranted = await _locationService.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationService.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // Get location data
    _locationData = await _locationService.getLocation();

    if (_locationData != null) {
      setState(() {
        _currentPosition = LatLng(
          _locationData!.latitude!,
          _locationData!.longitude!,
        );

        // Add a marker for current location
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: _currentPosition,
            infoWindow: const InfoWindow(
              title: 'Your Location',
              snippet: 'You are here',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );

        _isLoading = false;
      });

      // Move camera to current location
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition, zoom: 14.0),
        ),
      );
    } else {
      setState(() => _isLoading = false);
    }

    // Set up location change subscription
    _locationService.onLocationChanged.listen((LocationData currentLocation) {
      if (mounted &&
          currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          _currentPosition = LatLng(
            currentLocation.latitude!,
            currentLocation.longitude!,
          );

          // Update current location marker
          _markers.removeWhere(
            (marker) => marker.markerId.value == 'currentLocation',
          );
          _markers.add(
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: _currentPosition,
              infoWindow: const InfoWindow(
                title: 'Your Location',
                snippet: 'You are here',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if running on web platform
    final isWebPlatform = kIsWeb;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24), // More modern rounded corners
        child: Stack(
          children: [
            // For web platform, use an enhanced styled placeholder
            if (isWebPlatform)
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryBlue.withOpacity(0.8),
                      AppColors.lightBlue.withOpacity(0.6),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Abstract map-like pattern overlay
                    Opacity(
                      opacity: 0.1,
                      child: CustomPaint(
                        painter: GridPainter(),
                        size: Size.infinite,
                      ),
                    ),
                    // Central content
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.map,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'Interactive Map',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Location pins decoration
                    Positioned(
                      top: 40,
                      right: 60,
                      child: _buildLocationPin(
                        Colors.white.withOpacity(0.6),
                        24,
                      ),
                    ),
                    Positioned(
                      bottom: 50,
                      left: 80,
                      child: _buildLocationPin(
                        Colors.white.withOpacity(0.4),
                        16,
                      ),
                    ),
                  ],
                ),
              )
            // For mobile platforms, use styled Google Map
            else
              Theme(
                data: ThemeData(
                  // Apply custom styling to Google Maps controls
                  iconTheme: IconThemeData(color: AppColors.primaryOrange),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 14.0,
                  ),
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: widget.showUserLocation,
                  myLocationButtonEnabled: widget.showUserLocation,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                    _applyMapStyle(controller);
                  },
                ),
              ),
            // Loading indicator with improved visual
            if (_isLoading)
              Container(
                color: AppColors.backgroundGray.withOpacity(0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowColor.withOpacity(0.1),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryOrange,
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.future.then((controller) => controller.dispose());
    _animationController.dispose();
    super.dispose();
  }
}
