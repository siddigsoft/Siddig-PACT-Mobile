// lib/screens/components/visit_details_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/visit_model.dart';
import '../../theme/app_colors.dart';

class VisitDetailsSheet extends StatefulWidget {
  final Visit visit;
  final Function(Visit) onStatusChange;

  const VisitDetailsSheet({
    super.key,
    required this.visit,
    required this.onStatusChange,
  });

  @override
  State<VisitDetailsSheet> createState() => _VisitDetailsSheetState();
}

class _VisitDetailsSheetState extends State<VisitDetailsSheet> {
  late Visit _visit;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
  }

  void _updateVisitStatus(VisitStatus newStatus) {
    setState(() {
      _visit = _visit.copyWith(status: newStatus);
    });
    widget.onStatusChange(_visit);

    if (newStatus == VisitStatus.completed) {
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
                    _visit.title,
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
                    content: _visit.location ?? 'No location specified',
                  ),
                  const Divider(),

                  // Date/time section
                  _buildInfoSection(
                    icon: Icons.calendar_today,
                    iconColor: Colors.blue.shade400,
                    title: 'Scheduled Date',
                    content: _visit.scheduledDate != null
                        ? _visit.scheduledDate!.toLocal().toString().split(
                            '.',
                          )[0]
                        : 'Flexible Timing',
                  ),
                  const Divider(),

                  // Client info section
                  _buildInfoSection(
                    icon: Icons.person,
                    iconColor: Colors.purple.shade400,
                    title: 'Client Information',
                    content:
                        _visit.clientInfo ?? 'No client information provided',
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

  Widget _buildStatusBadge(VisitStatus status) {
    Color badgeColor;
    String statusText;

    switch (status) {
      case VisitStatus.pending:
        badgeColor = Colors.grey.shade500;
        statusText = 'Pending';
        break;
      case VisitStatus.available:
        badgeColor = Colors.blue.shade400;
        statusText = 'Available';
        break;
      case VisitStatus.assigned:
        badgeColor = Colors.blue.shade400;
        statusText = 'Assigned';
        break;
      case VisitStatus.inProgress:
        badgeColor = Colors.amber.shade700;
        statusText = 'In Progress';
        break;
      case VisitStatus.completed:
        badgeColor = Colors.green.shade500;
        statusText = 'Completed';
        break;
      case VisitStatus.cancelled:
        badgeColor = Colors.red.shade400;
        statusText = 'Cancelled';
        break;
      case VisitStatus.rejected:
        badgeColor = Colors.red.shade700;
        statusText = 'Rejected';
        break;
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
    // Different buttons based on current status
    switch (_visit.status) {
      case VisitStatus.pending:
      case VisitStatus.available:
      case VisitStatus.assigned:
        return _buildButton(
          label: 'Start Visit',
          icon: Icons.play_arrow,
          color: Colors.blue,
          onPressed: () => _updateVisitStatus(VisitStatus.inProgress),
        );

      case VisitStatus.inProgress:
        return Column(
          children: [
            _buildButton(
              label: 'Complete Visit',
              icon: Icons.check_circle,
              color: Colors.green,
              onPressed: () => _updateVisitStatus(VisitStatus.completed),
            ),
            const SizedBox(height: 16),
            _buildButton(
              label: 'Cancel Visit',
              icon: Icons.cancel,
              color: Colors.red,
              onPressed: () => _updateVisitStatus(VisitStatus.cancelled),
              filled: false,
            ),
          ],
        );

      case VisitStatus.completed:
        return _buildButton(
          label: 'Submit Report',
          icon: Icons.assignment,
          color: AppColors.primaryBlue,
          onPressed: _showReportDialog,
        );

      case VisitStatus.cancelled:
      case VisitStatus.rejected:
        return _buildButton(
          label: 'Reopen Visit',
          icon: Icons.refresh,
          color: Colors.blue,
          onPressed: () => _updateVisitStatus(VisitStatus.assigned),
          filled: false,
        );
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
