import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/site_assignment_service.dart';
import '../models/site_visit.dart';
import '../repositories/site_visit_repository.dart';
import '../theme/app_colors.dart';

class FieldOperationsScreen extends StatefulWidget {
  const FieldOperationsScreen({super.key});

  @override
  State<FieldOperationsScreen> createState() => _FieldOperationsScreenState();
}

class _FieldOperationsScreenState extends State<FieldOperationsScreen> {
  final SiteAssignmentService _assignmentService = SiteAssignmentService();
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  List<SiteVisit> _rankedVisits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSiteVisits();
  }

  Future<void> _loadSiteVisits() async {
    try {
      // TODO: Replace with actual repository call
      final visits = [
        SiteVisit(
          id: '1',
          siteId: 'SITE001',
          latitude: -1.2921,
          longitude: 36.8219,
          status: 'pending',
        ),
        // Add more test data
      ];

      final rankedVisits = await _assignmentService.rankSiteVisits(visits);
      
      setState(() {
        _rankedVisits = rankedVisits;
        _markers = _createMarkers(rankedVisits);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading site visits: $e')),
      );
    }
  }

  Set<Marker> _createMarkers(List<SiteVisit> visits) {
    return visits.map((visit) {
      return Marker(
        markerId: MarkerId(visit.id),
        position: LatLng(visit.latitude, visit.longitude),
        infoWindow: InfoWindow(
          title: 'Site ${visit.siteId}',
          snippet: visit.status,
        ),
      );
    }).toSet();
  }

  Future<void> _acceptVisit(SiteVisit visit) async {
    try {
      // TODO: Call repository to update visit status
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Site visit accepted')),
      );
      await _loadSiteVisits(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting visit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Field Operations',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 300,
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(-1.2921, 36.8219), // Nairobi
                      zoom: 12,
                    ),
                    markers: _markers,
                    onMapCreated: (controller) => _mapController = controller,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _rankedVisits.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final visit = _rankedVisits[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            'Site ${visit.siteId}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Status: ${visit.status}',
                            style: GoogleFonts.poppins(color: AppColors.textLight),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _acceptVisit(visit),
                            child: const Text('Accept Visit'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}