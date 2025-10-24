// lib/screens/components/visit_details_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/site_visit.dart';
import '../../models/visit_status.dart';
import '../../theme/app_colors.dart';

class VisitDetailsSheet extends StatefulWidget {
  final SiteVisit visit;
  final Function(String) onStatusChanged;
  final bool isTrackingJourney;
  final bool isNearDestination;
  final VoidCallback? onArrived;
  final VoidCallback? onGetDirections;

  const VisitDetailsSheet({
    super.key,
    required this.visit,
    required this.onStatusChanged,
    this.isTrackingJourney = false,
    this.isNearDestination = false,
    this.onArrived,
    this.onGetDirections,
  });

  @override
  State<VisitDetailsSheet> createState() => _VisitDetailsSheetState();
}

class _VisitDetailsSheetState extends State<VisitDetailsSheet> {
  late SiteVisit _visit;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
  }

  void _updateVisitStatus(String newStatus) {
    widget.onStatusChanged(newStatus);

    if (newStatus.toLowerCase() == 'completed') {
      _showReportDialog();
    }
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
        badgeColor = Colors.blue.shade400;
        statusText = 'Available';
        break;
      case 'assigned':
        badgeColor = Colors.blue.shade400;
        statusText = 'Assigned';
        break;
      case 'in_progress':
        badgeColor = Colors.amber.shade700;
        statusText = 'In Progress';
        break;
      case 'completed':
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
      case 'pending':
      case 'available':
      case 'assigned':
        return Column(
          children: [
            _buildButton(
              label: 'Start Visit',
              icon: Icons.play_arrow,
              color: Colors.blue,
              onPressed: () => _updateVisitStatus('in_progress'),
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

      case 'in_progress':
        return Column(
          children: [
            _buildButton(
              label: 'Complete Visit',
              icon: Icons.check_circle,
              color: Colors.green,
              onPressed: () => _updateVisitStatus('completed'),
            ),
            const SizedBox(height: 16),
            _buildButton(
              label: 'Cancel Visit',
              icon: Icons.cancel,
              color: Colors.red,
              onPressed: () => _updateVisitStatus('cancelled'),
              filled: false,
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
        return _buildButton(
          label: 'Submit Report',
          icon: Icons.assignment,
          color: AppColors.primaryBlue,
          onPressed: _showReportDialog,
        );

      case 'cancelled':
      case 'rejected':
        return _buildButton(
          label: 'Reopen Visit',
          icon: Icons.refresh,
          color: Colors.blue,
          onPressed: () => _updateVisitStatus('assigned'),
          filled: false,
        );
      default:
        return defaultButton;
    }
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
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: filled ? Colors.white : color),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? color : Colors.white,
          foregroundColor: filled ? Colors.white : color,
          side: filled ? null : BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, duration: 250.ms);
  }
}
