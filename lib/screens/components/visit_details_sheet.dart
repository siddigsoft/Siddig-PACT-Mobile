// lib/screens/components/visit_details_sheet.dart

import 'package:flutter/material.dart';
import 'dart:async'; // For TimeoutException
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/site_visit.dart';
import '../../models/visit_status.dart';
import '../../theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/staff_tracking_service.dart';
import '../../services/location_tracking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/offline_data_service.dart';
import 'report_form_sheet.dart';
import '../../widgets/claim_site_button.dart';
import '../../widgets/start_visit_button.dart';
import '../../widgets/complete_visit_button.dart';
import '../../widgets/accept_assignment_button.dart';

class VisitDetailsSheet extends StatefulWidget {
  final SiteVisit visit;
  final Future<void> Function(String) onStatusChanged;
  final Future<void> Function(String)? onReject; // New callback for rejection
  final bool isTrackingJourney;
  final bool isNearDestination;
  final VoidCallback? onArrived;
  final VoidCallback? onGetDirections;
  // New: whether the visit's report has already been submitted
  final bool reportSubmitted;
  // Callback to request opening the report submission form
  final VoidCallback? onSubmitReportRequested;

  const VisitDetailsSheet({
    super.key,
    required this.visit,
    required this.onStatusChanged,
    this.onReject,
    this.isTrackingJourney = false,
    this.isNearDestination = false,
    this.onArrived,
    this.onGetDirections,
    this.reportSubmitted = false,
    this.onSubmitReportRequested,
  });

  @override
  State<VisitDetailsSheet> createState() => _VisitDetailsSheetState();
}

class _VisitDetailsSheetState extends State<VisitDetailsSheet> {
  late SiteVisit _visit;
  bool _isUpdating = false;
  bool _isEndingVisit = false;
  bool _hasReport = false;
  bool _checkedReport = false;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
    // If already completed and we didn't get an explicit flag, probe for report existence
    if (_visit.status.toLowerCase() == 'completed' && !widget.reportSubmitted) {
      _probeReportExists();
    }
  }

  Future<void> _probeReportExists() async {
    try {
      final supabase = Supabase.instance.client;
      // Try online first
      try {
        final res = await supabase
            .from('reports')
            .select('id')
            .eq('site_visit_id', _visit.id)
            .limit(1);
        if (mounted) {
          setState(() {
            _hasReport = (res.isNotEmpty);
            _checkedReport = true;
          });
        }
        return;
      } catch (_) {}

      // Fallback to offline cache
      final offline = OfflineDataService();
      final cached = await offline.getCachedReports();
      final exists = cached.any((r) => r['site_visit_id'] == _visit.id);
      if (mounted) {
        setState(() {
          _hasReport = exists;
          _checkedReport = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkedReport = true;
        });
      }
    }
  }

  Future<void> _onEndVisitCaptureLocation() async {
    if (_isEndingVisit) return;
    setState(() => _isEndingVisit = true);

    // Show small progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProgressDialog(
          title: 'Ending visit',
          message: 'Capturing site location and stopping tracking...'),
    );

    try {
      // 1) Get precise current location
      final hasService = await Geolocator.isLocationServiceEnabled();
      if (!hasService) {
        throw Exception('Location services are disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission not granted');
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      // 2) Persist actual site coordinates in dedicated table
      // Reuse StaffTrackingService API which writes to `site_locations`
      // Acquire Supabase client explicitly (web build needs direct import) and record site location
      final staffService = StaffTrackingService(Supabase.instance.client);
      final ok = await staffService.recordSiteLocation(
        siteId: _visit.id,
        position: position,
        notes: 'Captured at end of visit',
      );

      if (!ok) {
        throw Exception('Failed to save site location');
      }

      // Optional: verify row exists (depends on RLS policies)
      try {
        final row = await Supabase.instance.client
            .from('site_locations')
            .select('site_id, latitude, longitude, accuracy, recorded_at')
            .eq('site_id', _visit.id)
            .single();
        debugPrint(
            '✅ Verified site location saved: lat=${row['latitude']}, lng=${row['longitude']}');
      } catch (e) {
        debugPrint('⚠️ Verification read failed (may be blocked by RLS): $e');
      }

      // 3) Stop ongoing user location tracking
      await LocationTrackingService().stopJourneyTracking();

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site location saved and tracking stopped.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end visit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isEndingVisit = false);
    }
  }

  void _updateVisitStatus(String newStatus) async {
    if (_isUpdating) return; // Guard against re-entry
    setState(() => _isUpdating = true);
    // Show a small progress dialog while updating
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProgressDialog(
          title: 'Please wait', message: 'Updating visit status...'),
    );

    try {
      bool shouldCloseSheet = false;
      // Ensure we don't hang forever if backend is slow
      await widget
          .onStatusChanged(newStatus)
          .timeout(const Duration(seconds: 20));
      
      // Update local state to reflect the change immediately
      if (mounted) {
        setState(() {
          _visit = _visit.copyWith(status: newStatus);
        });
      }

      // If we successfully marked as completed, close this bottom sheet so the parent can show the report form cleanly
      if (newStatus.toLowerCase() == 'completed') {
        shouldCloseSheet = true;
      }
    } on TimeoutException {
      // Inform and proceed to close the dialog anyway
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Updating took too long. Please check network and try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Surface error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to update visit status')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always close the progress dialog if it's still open
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // ignore if already closed
        }
        // If we marked completed, also close this sheet so the parent can present the report form without flicker
        try {
          // Using maybePop prevents exceptions if already closed
          Navigator.of(context).maybePop();
        } catch (_) {}
      }
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateVisitStatusAndShowReport() async {
    // 1. Update status to Completed
    // We can't easily await _updateVisitStatus because it returns void.
    // But we can replicate its logic or just call it and hope for the best, 
    // OR better, we can use the widget.onStatusChanged directly which returns Future<void>.
    
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    
    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProgressDialog(title: 'Updating', message: 'Completing visit...'),
    );

    try {
      // Call the parent callback directly to await it
      await widget.onStatusChanged('Completed');
      
      // Also stop tracking if needed (logic usually in parent, but let's be safe)
      // The parent _handleVisitStatusChanged handles stopTracking for 'Completed'.
      
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        setState(() => _isUpdating = false);
        
        // 2. Show Report Form immediately
        _showReportForm();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing visit: $e')),
        );
      }
    }
  }

  void _showReportForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportFormSheet(
        visit: _visit,
        onReportSubmitted: (report) {
          setState(() {
            _hasReport = true;
          });
          // Optionally close the details sheet too, or just let user see "View Report"
        },
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Visit Report'),
        content: const Text(
          'Would you like to submit a report for this visit now?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to report submission screen
              // TODO: Implement navigation to report screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle and header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Visit title and status badge
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _visit.siteName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(_visit.status),
              ],
            ),
          ),

          // Visit details
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address section
                  _buildInfoSection(
                    icon: Icons.location_on,
                    iconColor: Colors.red.shade400,
                    title: 'Location',
                    content: _visit.locationString,
                  ),
                  const Divider(),

                  // Date/time section
                  _buildInfoSection(
                    icon: Icons.calendar_today,
                    iconColor: Colors.blue.shade400,
                    title: 'Scheduled Date',
                    content: _visit.dueDate != null
                        ? _visit.dueDate!.toLocal().toString().split('.')[0]
                        : 'Flexible Timing',
                  ),
                  const Divider(),

                  // Client info section
                  _buildInfoSection(
                    icon: Icons.person,
                    iconColor: Colors.purple.shade400,
                    title: 'Client Information',
                    content: _visit.visitData?['client_info'] ??
                        'No client information provided',
                  ),
                  const Divider(),

                  // Notes section
                  _buildInfoSection(
                    icon: Icons.notes,
                    iconColor: Colors.amber.shade700,
                    title: 'Notes',
                    content: _visit.notes ?? 'No notes available',
                  ),
                  const Divider(),

                  // Action buttons based on current status
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = Colors.grey.shade500;
        statusText = 'Pending';
        break;
      case 'available':
      case 'dispatched': // New status
        badgeColor = Colors.blue.shade400;
        statusText = 'Dispatched';
        break;
      case 'assigned':
      case 'accept': // New status
      case 'accepted':
        badgeColor = Colors.blue.shade400;
        statusText = 'Accepted';
        break;
      case 'claimed':
        badgeColor = Colors.orange.shade400;
        statusText = 'Claimed - Awaiting Acceptance';
        break;
      case 'in_progress':
      case 'ongoing': // New status
        badgeColor = Colors.amber.shade700;
        statusText = 'Ongoing';
        break;
      case 'completed':
      case 'complete': // New status
        badgeColor = Colors.green.shade500;
        statusText = 'Completed';
        break;
      case 'cancelled':
        badgeColor = Colors.red.shade400;
        statusText = 'Cancelled';
        break;
      case 'rejected':
        badgeColor = Colors.red.shade700;
        statusText = 'Rejected';
        break;
      default:
        badgeColor = Colors.grey.shade500;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool filled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: color),
              label: Text(label, style: TextStyle(color: color)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  Widget _buildActionButtons() {
    // Show "Arrived" button if tracking and near destination
    if (widget.isTrackingJourney &&
        widget.isNearDestination &&
        widget.onArrived != null) {
      return Column(
        children: [
          _buildButton(
            label: 'Arrived at Destination',
            icon: Icons.location_on,
            color: AppColors.primaryOrange,
            onPressed: widget.onArrived!,
          ),
          const SizedBox(height: 8),
          Text(
            'You are within 50 meters of the destination',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (widget.onGetDirections != null)
            _buildButton(
              label: 'Get Directions',
              icon: Icons.directions,
              color: Colors.blue,
              onPressed: widget.onGetDirections!,
              filled: false,
            ),
        ],
      );
    }

    // Show tracking indicator if journey is active
    if (widget.isTrackingJourney) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryOrange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.navigation, color: AppColors.primaryOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Journey in Progress',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your route is being tracked. Click "Arrived" when you reach the destination.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.onGetDirections != null)
            _buildButton(
              label: 'Get Directions',
              icon: Icons.directions,
              color: Colors.blue,
              onPressed: widget.onGetDirections!,
              filled: false,
            ),
        ],
      );
    }

    // Default button if status doesn't match any case
    Widget defaultButton = _buildButton(
      label: 'View Details',
      icon: Icons.info_outline,
      color: Colors.grey,
      onPressed: () {},
      filled: false,
    );

    // Different buttons based on current status
    switch (_visit.status.toLowerCase()) {
      case 'dispatched':
      case 'available': // Keep for backward compatibility
        return Row(
          children: [
            Expanded(
              child: _buildButton(
                label: 'Reject',
                icon: Icons.close,
                color: Colors.red,
                onPressed: _showRejectionDialog,
                filled: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ClaimSiteButton(
                siteEntryId: _visit.id,
                siteName: _visit.siteName,
                onClaimSuccess: () {
                  setState(() {
                    _visit = _visit.copyWith(status: 'claimed');
                  });
                  widget.onStatusChanged('claimed');
                },
                onClaimError: () {
                  // Error handling is done in the button
                },
              ),
            ),
          ],
        );
      case 'accept':
      case 'accepted':
      case 'assigned':
      case 'claimed':
        // Check if assignment has been accepted
        final isAccepted = _visit.acceptedBy != null && _visit.acceptedAt != null;
        
        if (!isAccepted) {
          // Show Accept Assignment button
          return Column(
            children: [
              AcceptAssignmentButton(
                siteEntryId: _visit.id,
                siteName: _visit.siteName,
                onAcceptSuccess: () {
                  setState(() {
                    _visit = _visit.copyWith(
                      acceptedBy: Supabase.instance.client.auth.currentUser?.id,
                      acceptedAt: DateTime.now(),
                      status: 'accepted',
                    );
                  });
                  widget.onStatusChanged('accepted');
                },
                onAcceptError: () {
                  // Error handling is done in the button
                },
              ),
              const SizedBox(height: 16),
              if (widget.onGetDirections != null)
                _buildButton(
                  label: 'Get Directions',
                  icon: Icons.directions,
                  color: Colors.blue,
                  onPressed: widget.onGetDirections!,
                  filled: false,
                ),
            ],
          );
        } else {
          // Assignment accepted, show Start Visit button
          return Column(
            children: [
              StartVisitButton(
                visit: _visit,
                onStartSuccess: () {
                  setState(() {
                    _visit = _visit.copyWith(status: 'in_progress');
                  });
                  widget.onStatusChanged('in_progress');
                },
                onStartError: () {
                  // Error handling is done in the button
                },
              ),
              const SizedBox(height: 16),
              if (widget.onGetDirections != null)
                _buildButton(
                  label: 'Get Directions',
                  icon: Icons.directions,
                  color: Colors.blue,
                  onPressed: widget.onGetDirections!,
                  filled: false,
                ),
            ],
          );
        }
      case 'ongoing':
      case 'in_progress':
        return Column(
          children: [
            CompleteVisitButton(
              visit: _visit,
              onCompleteSuccess: () {
                setState(() {
                  _visit = _visit.copyWith(status: 'completed');
                });
                widget.onStatusChanged('completed');
              },
              onCompleteError: () {
                // Error handling is done in the button
              },
            ),
            const SizedBox(height: 16),
            if (widget.onGetDirections != null)
              _buildButton(
                label: 'Get Directions',
                icon: Icons.directions,
                color: Colors.blue,
                onPressed: widget.onGetDirections!,
                filled: false,
              ),
          ],
        );
      case 'completed':
      case 'complete':
        return _buildButton(
          label: _hasReport ? 'View Report' : 'Submit Report',
          icon: _hasReport ? Icons.description : Icons.assignment,
          color: _hasReport ? Colors.grey : Colors.green,
          onPressed: () {
            if (_hasReport) {
              // View report logic (maybe open PDF or details)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report already submitted')),
              );
            } else {
              _showReportForm();
            }
          },
          filled: !_hasReport,
        );
      default:
        return defaultButton;
    }
  }

  Future<void> _showRejectionDialog() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Visit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this visit:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context, reasonController.text);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason != null && widget.onReject != null) {
      setState(() => _isUpdating = true);
      try {
        await widget.onReject!(reason);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting visit: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }
}

class _ProgressDialog extends StatelessWidget {
  final String title;
  final String message;
  const _ProgressDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
