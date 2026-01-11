import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/reusable_app_bar.dart';
import '../widgets/custom_drawer_menu.dart';
import '../widgets/notifications_panel.dart';
import '../widgets/main_layout.dart';
import '../widgets/start_visit_dialog.dart';
import '../widgets/visit_report_dialog.dart';
import '../theme/app_colors.dart';
import '../services/location_service.dart';
import '../services/photo_upload_service.dart';
import '../services/advance_request_service.dart';
import '../models/visit_report.dart';
import '../models/visit_report_data.dart';
import '../widgets/request_advance_dialog.dart';

class FieldOperationsEnhancedScreen extends StatefulWidget {
  const FieldOperationsEnhancedScreen({super.key});

  @override
  State<FieldOperationsEnhancedScreen> createState() => _MMPScreenState();
}

// Alias for backward compatibility
typedef MMPScreen = FieldOperationsEnhancedScreen;

class _MMPScreenState extends State<MMPScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  bool _isLoading = true;
  bool _isCoordinator = false;
  bool _isDataCollector = false;
  String? _userId;
  String? _userStateId;
  String? _userLocalityId;
  String? _userStateName;
  String? _userLocalityName;
  
  // Tab states
  String _activeTab = 'my-assignments';
  String _enumeratorSubTab = 'claimable';
  String _mySitesSubTab = 'pending';
  
  // Site entries
  List<Map<String, dynamic>> _availableSites = [];
  List<Map<String, dynamic>> _smartAssignedSites = [];
  List<Map<String, dynamic>> _mySites = [];
  List<Map<String, dynamic>> _unsyncedCompletedVisits = [];
  List<Map<String, dynamic>> _coordinatorSites = [];
  
  // Advance requests map: siteId -> request data
  Map<String, Map<String, dynamic>> _advanceRequests = {};
  bool _loadingAdvanceRequests = false;
  
  // Grouped data
  Map<String, List<Map<String, dynamic>>> _groupedByStateLocality = {};
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _initializeMMP();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMMP() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _userId = user.id;

      // Get user profile to determine role
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('role, state_id, locality_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse != null) {
        final role = (profileResponse['role'] as String?)?.toLowerCase() ?? '';
        _isCoordinator = role == 'coordinator' || 
                        role == 'field_coordinator' ||
                        role == 'state_coordinator';
        _isDataCollector = role == 'datacollector' || 
                          role == 'enumerator' ||
                          role == 'data_collector';
        
        _userStateId = profileResponse['state_id'] as String?;
        _userLocalityId = profileResponse['locality_id'] as String?;
        
        // Query actual state and locality names from database
        await _loadLocationNames();
      }

      // Load data based on role
      // Coordinators should see the same MMP experience as data collectors
      if (_isDataCollector || _isCoordinator) {
        await _loadDataCollectorData();
        _setupRealtimeSubscription();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error initializing MMP: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    try {
      _realtimeChannel?.unsubscribe();
      
      _realtimeChannel = Supabase.instance.client
          .channel('mmp_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'mmp_site_entries',
            callback: (payload) {
              debugPrint('mmp_site_entries changed, reloading...');
              if (_isDataCollector || _isCoordinator) {
                _loadDataCollectorData();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'down_payment_requests',
            callback: (payload) {
              debugPrint('down_payment_requests changed, reloading...');
              if (_isDataCollector || _isCoordinator) {
                _loadAdvanceRequests();
                setState(() {});
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up real-time subscription: $e');
    }
  }

  Future<void> _loadDataCollectorData() async {
    try {
      if (_userId == null) return;

      // Load available sites (Dispatched, not accepted, in collector's area)
      await _loadAvailableSites();
      
      // Load smart assigned sites (status = 'Assigned', accepted_by = currentUser, not cost-acknowledged)
      await _loadSmartAssignedSites();
      
      // Load my sites (all sites accepted by this collector)
      await _loadMySites();
      
      // Load unsynced completed visits (from offline DB if available)
      await _loadUnsyncedCompletedVisits();
      
      // Load advance requests
      await _loadAdvanceRequests();
      
      // Group available sites by state-locality
      _groupAvailableSites();
      
    } catch (e) {
      debugPrint('Error loading data collector data: $e');
    }
  }

  Future<void> _loadLocationNames() async {
    try {
      // Load state name from hub_states table
      if (_userStateId != null) {
        final hubState = await Supabase.instance.client
            .from('hub_states')
            .select('state_name')
            .eq('state_id', _userStateId!)
            .maybeSingle();
        
        if (hubState != null) {
          _userStateName = hubState['state_name'] as String?;
        } else {
          // Fallback: Try sites_registry if hub_states doesn't have it
          final registryState = await Supabase.instance.client
              .from('sites_registry')
              .select('state_name')
              .eq('state_id', _userStateId!)
              .limit(1)
              .maybeSingle();
          
          _userStateName = registryState?['state_name'] as String?;
        }
        
        debugPrint('Loaded state name: $_userStateName for state_id: $_userStateId');
      }
      
      // Load locality name from sites_registry table
      if (_userLocalityId != null && _userStateId != null) {
        final locality = await Supabase.instance.client
            .from('sites_registry')
            .select('locality_name')
            .eq('locality_id', _userLocalityId!)
            .eq('state_id', _userStateId!)
            .limit(1)
            .maybeSingle();
        
        _userLocalityName = locality?['locality_name'] as String?;
        debugPrint('Loaded locality name: $_userLocalityName for locality_id: $_userLocalityId');
      }
    } catch (e) {
      debugPrint('Error loading location names: $e');
      // If lookup fails, we'll show all dispatched sites (fallback behavior)
    }
  }

  Future<void> _loadAvailableSites() async {
    try {
      if (_userId == null) return;

      debugPrint('Loading available sites...');
      debugPrint('User state: $_userStateName (ID: $_userStateId)');
      debugPrint('User locality: $_userLocalityName (ID: $_userLocalityId)');

      // Build query step by step
      var query = Supabase.instance.client
          .from('mmp_site_entries')
          .select('*')
          .ilike('status', 'Dispatched');

      // Filter by location if names are available
      // Only filter if we have actual names, not IDs
      if (_userLocalityName != null && _userLocalityName!.isNotEmpty) {
        debugPrint('Filtering by locality: $_userLocalityName');
        query = query.ilike('locality', _userLocalityName!);
      } else if (_userStateName != null && _userStateName!.isNotEmpty) {
        debugPrint('Filtering by state: $_userStateName');
        query = query.ilike('state', _userStateName!);
      } else {
        // If no location info, show all dispatched sites (remove location filter)
        debugPrint('No location info available - showing all dispatched sites');
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(1000);

      if (response != null) {
        // Filter out sites that have been accepted (accepted_by is not null)
        _availableSites = (response as List)
            .map((e) => e as Map<String, dynamic>)
            .where((site) => site['accepted_by'] == null)
            .toList();
        
        debugPrint('Loaded ${_availableSites.length} available sites');
        
        // Debug: Print first few sites for verification
        if (_availableSites.isNotEmpty) {
          debugPrint('Sample site: ${_availableSites.first['site_name']} - State: ${_availableSites.first['state']} - Locality: ${_availableSites.first['locality']}');
        }
      } else {
        debugPrint('No response from query');
        _availableSites = [];
      }
    } catch (e) {
      debugPrint('Error loading available sites: $e');
      _availableSites = [];
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sites: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSmartAssignedSites() async {
    try {
      if (_userId == null) return;

      final response = await Supabase.instance.client
          .from('mmp_site_entries')
          .select('*')
          .ilike('status', 'Assigned')
          .eq('accepted_by', _userId!)
          .order('created_at', ascending: false)
          .limit(1000);

      if (response != null) {
        final allSites = (response as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        
        // Filter out cost-acknowledged sites
        _smartAssignedSites = allSites.where((site) {
          final additionalData = site['additional_data'] as Map<String, dynamic>?;
          final costAcknowledged = site['cost_acknowledged'] ?? 
                                   additionalData?['cost_acknowledged'] ?? 
                                   false;
          return !costAcknowledged;
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading smart assigned sites: $e');
    }
  }

  Future<void> _loadMySites() async {
    try {
      if (_userId == null) return;

      final response = await Supabase.instance.client
          .from('mmp_site_entries')
          .select('*')
          .eq('accepted_by', _userId!)
          .order('created_at', ascending: false)
          .limit(1000);

      if (response != null) {
        _mySites = (response as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading my sites: $e');
    }
  }

  Future<void> _loadUnsyncedCompletedVisits() async {
    // This would load from offline DB if you have one
    // For now, we'll check for completed sites that might be unsynced
    try {
      if (_userId == null) return;

      final response = await Supabase.instance.client
          .from('mmp_site_entries')
          .select('*')
          .eq('accepted_by', _userId!)
          .ilike('status', 'Completed')
          .order('created_at', ascending: false)
          .limit(100);

      if (response != null) {
        // Filter for potentially unsynced visits (you may need additional logic)
        _unsyncedCompletedVisits = (response as List)
            .map((e) => e as Map<String, dynamic>)
            .where((site) {
              // Add logic to determine if unsynced
              return true; // Placeholder
            })
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading unsynced completed visits: $e');
    }
  }

  Future<void> _loadAdvanceRequests() async {
    try {
      if (_userId == null) return;

      setState(() => _loadingAdvanceRequests = true);

      // Load all advance requests for this user
      final response = await Supabase.instance.client
          .from('down_payment_requests')
          .select('*')
          .eq('requested_by', _userId!)
          .order('created_at', ascending: false);

      if (response != null) {
        // Map requests by site ID (keep most recent for each site)
        final requestsMap = <String, Map<String, dynamic>>{};
        for (final request in response) {
          final siteId = (request['mmp_site_entry_id'] as String?) ??
                         (request['site_visit_id'] as String?);
          if (siteId != null && !requestsMap.containsKey(siteId)) {
            requestsMap[siteId] = request as Map<String, dynamic>;
          }
        }

        setState(() {
          _advanceRequests = requestsMap;
          _loadingAdvanceRequests = false;
        });
      } else {
        setState(() {
          _advanceRequests = {};
          _loadingAdvanceRequests = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading advance requests: $e');
      setState(() {
        _advanceRequests = {};
        _loadingAdvanceRequests = false;
      });
    }
  }

  void _groupAvailableSites() {
    _groupedByStateLocality = {};
    for (final site in _availableSites) {
      final state = site['state'] as String? ?? 'Unknown State';
      final locality = site['locality'] as String? ?? 'Unknown Locality';
      final key = '$state - $locality';
      _groupedByStateLocality.putIfAbsent(key, () => []).add(site);
    }
  }

  Future<void> _loadCoordinatorData() async {
    try {
      if (_userId == null) return;

      // Load sites forwarded to this coordinator
      final response = await Supabase.instance.client
          .from('mmp_site_entries')
          .select('*')
          .eq('forwarded_to_user_id', _userId!)
          .order('created_at', ascending: false)
          .limit(1000);

      if (response != null) {
        _coordinatorSites = (response as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading coordinator data: $e');
    }
  }

  Future<void> _claimSite(Map<String, dynamic> site) async {
    try {
      if (_userId == null) return;

      // Use atomic claim RPC for dispatched sites (first-claim system)
      try {
        final result = await Supabase.instance.client
            .rpc('claim_site_visit', params: {
              'p_site_id': site['id'],
              'p_user_id': _userId!,
            });

        final claimResult = result as Map<String, dynamic>?;
        
        if (claimResult == null || (claimResult['success'] as bool?) != true) {
          String description = claimResult?['message'] as String? ?? 'Could not claim site';
          
          if (claimResult?['error'] == 'ALREADY_CLAIMED') {
            description = 'Another enumerator claimed this site first. Try a different site.';
          } else if (claimResult?['error'] == 'CLAIM_IN_PROGRESS') {
            description = 'Someone else is claiming this site right now. Try again in a moment.';
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(description),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // RPC succeeded
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Site claimed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // RPC failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().contains('already') 
                  ? 'Could not claim this site. It may have been claimed by another enumerator.'
                  : 'Error claiming site: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site claimed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload data
      await _loadDataCollectorData();
      setState(() {});
    } catch (e) {
      debugPrint('Error claiming site: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestAdvance(Map<String, dynamic> site) async {
    try {
      if (_userId == null) return;

      final transportFee = (site['transport_fee'] as num?)?.toDouble() ?? 0.0;
      if (transportFee <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This site has no transport fee'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final siteName = site['site_name'] ?? site['siteName'] ?? 'Unknown Site';
      final hubId = site['hub_id'] ?? site['hubId'];
      final hubName = site['hub_name'] ?? 
                      site['hubName'] ?? 
                      site['hub_office'] ?? 
                      site['hubOffice'];

      // Show request dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => RequestAdvanceDialog(
          site: site,
          transportationBudget: transportFee,
          hubId: hubId,
          hubName: hubName,
        ),
      );

      if (result == null || result['success'] != true) return;

      final requestedAmount = (result['requestedAmount'] as num).toDouble();
      final paymentType = result['paymentType'] as String;
      final justification = result['justification'] as String;
      
      // Properly convert installmentPlan from List<dynamic> to List<Map<String, dynamic>>
      List<Map<String, dynamic>> installmentPlan = [];
      if (result['installmentPlan'] != null) {
        final planList = result['installmentPlan'] as List?;
        if (planList != null && planList.isNotEmpty) {
          installmentPlan = planList
              .map((e) => e as Map<String, dynamic>)
              .toList();
        }
      }

      // Get user role
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role, hub_id')
          .eq('id', _userId!)
          .maybeSingle();

      final role = (profile?['role'] as String?)?.toLowerCase() ?? '';
      final requesterRole = (role == 'coordinator' || 
                            role == 'field_coordinator' || 
                            role == 'state_coordinator')
          ? 'coordinator'
          : 'dataCollector';

      final finalHubId = hubId ?? profile?['hub_id'] as String?;

      // Create advance request
      final newRequest = await Supabase.instance.client
          .from('down_payment_requests')
          .insert({
            'mmp_site_entry_id': site['id'],
            'site_name': siteName,
            'requested_by': _userId,
            'requester_role': requesterRole,
            'hub_id': finalHubId,
            'hub_name': hubName,
            'total_transportation_budget': transportFee,
            'requested_amount': requestedAmount,
            'payment_type': paymentType,
            'installment_plan': installmentPlan,
            'justification': justification,
            'supporting_documents': [],
            'status': 'pending_supervisor',
            'supervisor_status': 'pending',
          })
          .select()
          .single();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Advance request submitted successfully. Waiting for supervisor approval.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload advance requests
      await _loadAdvanceRequests();
      setState(() {});

    } catch (e) {
      debugPrint('Error requesting advance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _shouldShowRequestAdvance(Map<String, dynamic> site) {
    // Only show for accepted or in-progress sites owned by current user
    final status = (site['status'] as String? ?? '').toLowerCase();
    final isAcceptedOrOngoing = status == 'accepted' || 
                                status == 'assigned' || 
                                status == 'in progress' || 
                                status == 'in_progress' || 
                                status == 'ongoing';
    final isOwner = site['accepted_by'] == _userId;
    final transportFee = (site['transport_fee'] as num?)?.toDouble() ?? 0.0;
    final hasTransportBudget = transportFee > 0;

    return isAcceptedOrOngoing && isOwner && hasTransportBudget;
  }

  Widget _buildRequestAdvanceWidget(Map<String, dynamic> site) {
    final siteId = site['id'] as String? ?? '';
    final existingRequest = _advanceRequests[siteId];

    // If request exists, show status badge
    if (existingRequest != null) {
      return _buildAdvanceStatusBadge(existingRequest);
    }

    // Show Request Advance button
    return ElevatedButton.icon(
      onPressed: () => _requestAdvance(site),
      icon: const Icon(Icons.payment, size: 18),
      label: const Text('Request Advance'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildAdvanceStatusBadge(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? 'pending_supervisor';
    final badgeInfo = AdvanceRequestService.getStatusBadge(status);
    final badgeColor = badgeInfo['color'] as Color;
    final badgeLabel = badgeInfo['label'] as String;
    final badgeIcon = badgeInfo['icon'] as IconData;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 18, color: badgeColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              badgeLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    Map<String, dynamic> site, {
    required String status,
    required bool showClaimButton,
    required bool showAcknowledgeButton,
    required bool showVisitActions,
  }) {
    final buttons = <Widget>[];

    // Claim Button
    if (showClaimButton) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _claimSite(site),
            icon: const Icon(Icons.handshake, size: 18),
            label: const Text('Claim Site'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );
    }

    // Acknowledge Cost Button
    if (showAcknowledgeButton) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _acknowledgeCost(site),
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Acknowledge Cost'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );
    }

    // Visit Actions
    if (showVisitActions) {
      // Request Advance Button (for accepted/in-progress sites with transport fee)
      if (_shouldShowRequestAdvance(site)) {
        buttons.add(
          Expanded(
            child: _buildRequestAdvanceWidget(site),
          ),
        );
      }

      // Start Visit Button (for accepted/assigned sites) - now shows even if Request Advance is shown
      if ((status.toString().toLowerCase() == 'accepted' || 
           status.toString().toLowerCase() == 'assigned') &&
          site['accepted_by'] == _userId) {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _startVisit(site),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start Visit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }

      // Complete Visit Button
      if ((status.toString().toLowerCase() == 'in progress' || 
           status.toString().toLowerCase() == 'ongoing') &&
          site['accepted_by'] == _userId) {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _completeVisit(site),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    // Use Row with Expanded widgets - they'll share space equally
    return Row(
      children: buttons,
    );
  }

  Future<void> _acknowledgeCost(Map<String, dynamic> site) async {
    // Show cost acknowledgment dialog
    final acknowledged = await showDialog<bool>(
      context: context,
      builder: (context) => _CostAcknowledgmentDialog(site: site),
    );

    if (acknowledged != true) return;

    try {
      final now = DateTime.now().toIso8601String();
      
      await Supabase.instance.client
          .from('mmp_site_entries')
          .update({
            'status': 'accepted',
            'cost_acknowledged': true,
            'cost_acknowledged_at': now,
            'cost_acknowledged_by': _userId,
            'accepted_at': now,
            'accepted_by': _userId,
            'updated_at': now,
            'additional_data': {
              ...(site['additional_data'] as Map<String, dynamic>? ?? {}),
              'cost_acknowledged': true,
              'cost_acknowledged_at': now,
              'cost_acknowledged_by': _userId,
            },
          })
          .eq('id', site['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cost acknowledged. Site moved to My Sites.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadDataCollectorData();
      setState(() {});
    } catch (e) {
      debugPrint('Error acknowledging cost: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startVisit(Map<String, dynamic> site) async {
    try {
      // Check location permissions
      final hasPermission = await LocationService.checkPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to start a visit.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StartVisitDialog(
          site: site,
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      );

      if (confirmed != true) return;

      // Get current location
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get location. Visit will start without location.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      final now = DateTime.now().toIso8601String();
      final siteStatus = (site['status'] as String? ?? '').toLowerCase();
      final isAssigned = siteStatus == 'assigned' && site['accepted_by'] == null;

      // Build update data
      final updateData = <String, dynamic>{
        'status': 'In Progress',
        'visit_started_at': now,
        'visit_started_by': _userId,
        'updated_at': now,
      };

      // Add location to additional_data if available
      if (position != null) {
        final additionalData = site['additional_data'] as Map<String, dynamic>? ?? {};
        additionalData['start_location'] = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': now,
        };
        updateData['additional_data'] = additionalData;
      }

      // If site was "assigned" (not yet accepted), auto-accept and set fees
      if (isAssigned) {
        updateData['accepted_by'] = _userId;
        updateData['accepted_at'] = now;

        // Fetch fresh site data to get latest fees
        final freshSite = await Supabase.instance.client
            .from('mmp_site_entries')
            .select('enumerator_fee, transport_fee, cost')
            .eq('id', site['id'])
            .maybeSingle();

        // Calculate fees if missing
        var enumeratorFee = (freshSite?['enumerator_fee'] as num?)?.toDouble() ?? 0.0;
        final transportFee = (freshSite?['transport_fee'] as num?)?.toDouble() ?? 
                            (site['transport_fee'] as num?)?.toDouble() ?? 0.0;

        // Calculate total cost
        final calculatedCost = enumeratorFee + transportFee;

        if (enumeratorFee > 0 || calculatedCost > 0) {
          updateData['enumerator_fee'] = enumeratorFee;
          updateData['transport_fee'] = transportFee;
          updateData['cost'] = calculatedCost;
        }
      }

      // Update database
      await Supabase.instance.client
          .from('mmp_site_entries')
          .update(updateData)
          .eq('id', site['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit started successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload data
      await _loadDataCollectorData();
      setState(() {});

    } catch (e) {
      debugPrint('Error starting visit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeVisit(Map<String, dynamic> site) async {
    try {
      // Show visit report dialog
      final reportData = await showDialog<VisitReportData>(
        context: context,
        builder: (context) => VisitReportDialog(
          site: site,
          onSubmit: (data) => Navigator.of(context).pop(data),
        ),
      );

      if (reportData == null) return;

      // Get final location
      final position = reportData.coordinates ?? 
                       await LocationService.getCurrentLocation();

      final now = DateTime.now().toIso8601String();

      // Upload photos
      List<String> photoUrls = [];
      if (reportData.photos.isNotEmpty) {
        photoUrls = await PhotoUploadService.uploadPhotos(
          site['id'].toString(),
          reportData.photos,
        );
      }

      // Create visit report
      final report = VisitReport(
        siteId: site['id'].toString(),
        activities: reportData.activities,
        notes: reportData.notes,
        durationMinutes: reportData.durationMinutes,
        latitude: position?.latitude,
        longitude: position?.longitude,
        accuracy: position?.accuracy,
        photoUrls: photoUrls,
        submittedAt: DateTime.now(),
      );

      // Save report to database
      final savedReport = await Supabase.instance.client
          .from('reports')
          .insert(report.toJson(submittedBy: _userId))
          .select()
          .single();

      // Link photos to report
      if (photoUrls.isNotEmpty && savedReport != null) {
        final reportPhotos = photoUrls.map((url) => {
          'report_id': savedReport['id'],
          'photo_url': url,
          'storage_path': url, // Use URL as storage path if separate path not available
        }).toList();

        await Supabase.instance.client
            .from('report_photos')
            .insert(reportPhotos);
      }

      // Update site status
      final updateData = <String, dynamic>{
        'status': 'Completed',
        'visit_completed_at': now,
        'visit_completed_by': _userId,
        'updated_at': now,
        'additional_data': {
          ...(site['additional_data'] as Map<String, dynamic>? ?? {}),
          'visit_report_submitted': true,
          'visit_report_id': savedReport['id'],
          'visit_report_submitted_at': now,
          if (position != null)
            'final_location': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
            },
        },
      };

      // Ensure visit_completed_at is set
      final currentSite = await Supabase.instance.client
          .from('mmp_site_entries')
          .select('visit_completed_at, visit_completed_by')
          .eq('id', site['id'])
          .maybeSingle();

      if (currentSite?['visit_completed_at'] == null) {
        updateData['visit_completed_at'] = now;
      }
      if (currentSite?['visit_completed_by'] == null) {
        updateData['visit_completed_by'] = _userId;
      }

      await Supabase.instance.client
          .from('mmp_site_entries')
          .update(updateData)
          .eq('id', site['id']);

      // Save GPS to site_locations table
      if (position != null) {
        await Supabase.instance.client
            .from('site_locations')
            .insert({
              'site_id': site['id'],
              'user_id': _userId,
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy ?? 10,
              'notes': 'Visit end location',
              'recorded_at': now,
            });
      }

      // Create wallet transaction (optional - you may need to implement this)
      try {
        // TODO: Call your wallet transaction creation function if needed
        // await createSiteVisitWalletTransaction(
        //   siteVisitId: site['id'],
        //   description: 'Site visit completed: ${site['site_name']}',
        // );
      } catch (e) {
        debugPrint('Error creating wallet transaction: $e');
        // Don't fail the entire operation
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit completed and report submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload data
      await _loadDataCollectorData();
      setState(() {});

    } catch (e) {
      debugPrint('Error completing visit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredSites(List<Map<String, dynamic>> sites) {
    if (_searchQuery.isEmpty) return sites;
    
    final query = _searchQuery.toLowerCase();
    return sites.where((site) {
      final siteName = (site['site_name'] ?? site['siteName'] ?? '').toString().toLowerCase();
      final siteCode = (site['site_code'] ?? site['siteCode'] ?? '').toString().toLowerCase();
      final state = (site['state'] ?? '').toString().toLowerCase();
      final locality = (site['locality'] ?? '').toString().toLowerCase();
      
      return siteName.contains(query) ||
             siteCode.contains(query) ||
             state.contains(query) ||
             locality.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentIndex: 1, // MMP is typically index 1
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.backgroundGray,
        drawer: CustomDrawerMenu(
          currentUser: Supabase.instance.client.auth.currentUser,
          onClose: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        body: SafeArea(
          child: Column(
            children: [
              ReusableAppBar(
                title: 'MMP Management',
                scaffoldKey: _scaffoldKey,
                showLanguageSwitcher: true,
                showNotifications: true,
                onNotificationTap: () => NotificationsPanel.show(context),
                showUserAvatar: true,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_isDataCollector || _isCoordinator)
                        ? _buildDataCollectorView()
                        : _buildNoAccessView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have permission to access this page.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCollectorView() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Assignments',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Claim, manage, and complete site visits',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Search sites...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        
        // Tabs
        Container(
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      'claimable',
                      'Claimable',
                      Icons.handshake,
                      _availableSites.length,
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      'assigned',
                      'Assigned',
                      Icons.assignment,
                      _smartAssignedSites.length,
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      'my-sites',
                      'My Sites',
                      Icons.location_on,
                      _mySites.length,
                    ),
                  ),
                ],
              ),
              if (_enumeratorSubTab == 'my-sites') ...[
                const Divider(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: _buildSubTabButton('pending', 'Inbox', _getPendingCount()),
                    ),
                    Expanded(
                      child: _buildSubTabButton('drafts', 'Drafts', _getDraftsCount()),
                    ),
                    Expanded(
                      child: _buildSubTabButton('outbox', 'Outbox', _unsyncedCompletedVisits.length),
                    ),
                    Expanded(
                      child: _buildSubTabButton('sent', 'Sent', _getSentCount()),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _buildDataCollectorContent(),
        ),
      ],
    );
  }

  Widget _buildTabButton(String tab, String label, IconData icon, int count) {
    final isActive = _enumeratorSubTab == tab;
    return InkWell(
      onTap: () => setState(() => _enumeratorSubTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primaryBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: isActive ? AppColors.primaryBlue : AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? AppColors.primaryBlue : AppColors.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryBlue.withOpacity(0.1) : AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primaryBlue : AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton(String tab, String label, int count) {
    final isActive = _mySitesSubTab == tab;
    return InkWell(
      onTap: () => setState(() => _mySitesSubTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryBlue.withOpacity(0.1) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primaryBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppColors.primaryBlue : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isActive ? AppColors.primaryBlue : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCollectorContent() {
    switch (_enumeratorSubTab) {
      case 'claimable':
        return _buildClaimableSites();
      case 'assigned':
        return _buildSmartAssignedSites();
      case 'my-sites':
        return _buildMySitesContent();
      default:
        return const SizedBox();
    }
  }

  Widget _buildClaimableSites() {
    final filtered = _getFilteredSites(_availableSites);
    
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text(
                'No sites available',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No sites available in your area yet.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group by state-locality
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final site in filtered) {
      final state = site['state'] as String? ?? 'Unknown State';
      final locality = site['locality'] as String? ?? 'Unknown Locality';
      final key = '$state - $locality';
      grouped.putIfAbsent(key, () => []).add(site);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First-Come, First-Served',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Claim Site" to assign a site to yourself. Be quick - other enumerators can see these sites too!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Grouped sites
        ...grouped.entries.map((entry) => _buildSiteGroup(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildSiteGroup(String title, List<Map<String, dynamic>> sites) {
    return ExpansionTile(
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${sites.length} site${sites.length != 1 ? 's' : ''}',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.textLight,
        ),
      ),
      children: sites.map((site) => _buildSiteCard(site, showClaimButton: true)).toList(),
    );
  }

  Widget _buildSmartAssignedSites() {
    final filtered = _getFilteredSites(_smartAssignedSites);
    
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text(
                'No assigned sites',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No sites assigned to you yet.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sites under this category are mandatory to be visited. If you have any issues, please contact your immediate supervisors.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...filtered.map((site) => _buildSiteCard(site, showAcknowledgeButton: true)),
      ],
    );
  }

  Widget _buildMySitesContent() {
    List<Map<String, dynamic>> sitesToShow = [];
    
    switch (_mySitesSubTab) {
      case 'pending':
        sitesToShow = _mySites.where((site) {
          final status = (site['status'] as String? ?? '').toLowerCase();
          return status == 'accepted' || 
                 status == 'assigned' || 
                 status == 'dispatched' ||
                 status == 'pending';
        }).toList();
        break;
      case 'drafts':
        sitesToShow = _mySites.where((site) {
          final status = (site['status'] as String? ?? '').toLowerCase();
          return status == 'in progress' || 
                 status == 'in_progress' || 
                 status == 'ongoing';
        }).toList();
        break;
      case 'outbox':
        sitesToShow = _unsyncedCompletedVisits;
        break;
      case 'sent':
        sitesToShow = _mySites.where((site) {
          final status = (site['status'] as String? ?? '').toLowerCase();
          return status == 'completed' || status == 'complete';
        }).where((site) {
          // Exclude unsynced
          return !_unsyncedCompletedVisits.any((uv) => uv['id'] == site['id']);
        }).toList();
        break;
    }

    final filtered = _getFilteredSites(sitesToShow);
    
    if (filtered.isEmpty) {
      String message = 'No sites found';
      switch (_mySitesSubTab) {
        case 'pending':
          message = 'No pending visits found.';
          break;
        case 'drafts':
          message = 'No in-progress or ongoing site visits found. Start a visit to see it here.';
          break;
        case 'outbox':
          message = 'No completed visits waiting to sync. All visits have been submitted.';
          break;
        case 'sent':
          message = 'No completed sites found.';
          break;
      }
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: filtered.map((site) => _buildSiteCard(
        site,
        showVisitActions: true,
      )).toList(),
    );
  }

  Widget _buildSiteCard(
    Map<String, dynamic> site, {
    bool showClaimButton = false,
    bool showAcknowledgeButton = false,
    bool showVisitActions = false,
  }) {
    final siteName = site['site_name'] ?? site['siteName'] ?? 'Unknown Site';
    final siteCode = site['site_code'] ?? site['siteCode'] ?? '';
    final state = site['state'] ?? '';
    final locality = site['locality'] ?? '';
    final status = site['status'] ?? 'Pending';
    final enumeratorFee = site['enumerator_fee'] ?? 0;
    final transportFee = site['transport_fee'] ?? 0;
    final cost = site['cost'] ?? (enumeratorFee + transportFee);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.backgroundGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siteName.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$locality, $state',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                    if (siteCode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Code: $siteCode',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          
          if (cost > 0 || enumeratorFee > 0 || transportFee > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (enumeratorFee > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collector Fee',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textLight,
                          ),
                        ),
                        Text(
                          '${enumeratorFee.toStringAsFixed(0)} SDG',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  if (transportFee > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transport',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textLight,
                          ),
                        ),
                        Text(
                          '${transportFee.toStringAsFixed(0)} SDG',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textLight,
                        ),
                      ),
                      Text(
                        '${cost.toStringAsFixed(0)} SDG',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          _buildActionButtons(
            site,
            status: status,
            showClaimButton: showClaimButton,
            showAcknowledgeButton: showAcknowledgeButton,
            showVisitActions: showVisitActions,
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorView() {
    final filtered = _getFilteredSites(_coordinatorSites);
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_user, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verified Sites',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Sites forwarded to you for verification',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Search sites...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        
        // Sites list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text(
                          'No sites found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No sites have been forwarded to you yet.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: filtered.map((site) => _buildCoordinatorSiteCard(site)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildCoordinatorSiteCard(Map<String, dynamic> site) {
    final siteName = site['site_name'] ?? site['siteName'] ?? 'Unknown Site';
    final siteCode = site['site_code'] ?? site['siteCode'] ?? '';
    final state = site['state'] ?? '';
    final locality = site['locality'] ?? '';
    final status = site['status'] ?? 'Pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.backgroundGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siteName.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$locality, $state',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                    if (siteCode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Code: $siteCode',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'complete') return Colors.green;
    if (s == 'in progress' || s == 'in_progress' || s == 'ongoing') return Colors.blue;
    if (s == 'pending' || s == 'assigned' || s == 'dispatched') return Colors.orange;
    if (s == 'verified') return Colors.purple;
    if (s == 'rejected') return Colors.red;
    return AppColors.textLight;
  }

  int _getPendingCount() {
    return _mySites.where((site) {
      final status = (site['status'] as String? ?? '').toLowerCase();
      return status == 'accepted' || 
             status == 'assigned' || 
             status == 'dispatched' ||
             status == 'pending';
    }).length;
  }

  int _getDraftsCount() {
    return _mySites.where((site) {
      final status = (site['status'] as String? ?? '').toLowerCase();
      return status == 'in progress' || 
             status == 'in_progress' || 
             status == 'ongoing';
    }).length;
  }

  int _getSentCount() {
    return _mySites.where((site) {
      final status = (site['status'] as String? ?? '').toLowerCase();
      return status == 'completed' || status == 'complete';
    }).where((site) {
      return !_unsyncedCompletedVisits.any((uv) => uv['id'] == site['id']);
    }).length;
  }
}

// Cost Acknowledgment Dialog
class _CostAcknowledgmentDialog extends StatefulWidget {
  final Map<String, dynamic> site;

  const _CostAcknowledgmentDialog({required this.site});

  @override
  State<_CostAcknowledgmentDialog> createState() => _CostAcknowledgmentDialogState();
}

class _CostAcknowledgmentDialogState extends State<_CostAcknowledgmentDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final enumeratorFee = site['enumerator_fee'] ?? 0;
    final transportFee = site['transport_fee'] ?? 0;
    final totalCost = site['cost'] ?? (enumeratorFee + transportFee);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost Acknowledgment',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Site: ${site['site_name'] ?? site['siteName'] ?? 'Unknown'}',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildCostRow('Data Collector Fee', enumeratorFee),
                  const Divider(),
                  _buildCostRow('Transport Fee', transportFee),
                  const Divider(),
                  _buildCostRow('Total Cost', totalCost, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: (value) => setState(() => _acknowledged = value ?? false),
              title: Text(
                'I acknowledge receipt of the cost details',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _acknowledged ? () => Navigator.of(context).pop(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Acknowledge'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, num amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(0)} SDG',
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal ? AppColors.primaryBlue : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

