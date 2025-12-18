import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_design_system.dart';
import '../widgets/app_widgets.dart';
import '../providers/offline_provider.dart';
import '../models/site_visit.dart';

class AcceptAssignmentButton extends ConsumerStatefulWidget {
  final String siteEntryId;
  final String siteName;
  final VoidCallback? onAcceptSuccess;
  final VoidCallback? onAcceptError;

  const AcceptAssignmentButton({
    super.key,
    required this.siteEntryId,
    required this.siteName,
    this.onAcceptSuccess,
    this.onAcceptError,
  });

  @override
  ConsumerState<AcceptAssignmentButton> createState() => _AcceptAssignmentButtonState();
}

class _AcceptAssignmentButtonState extends ConsumerState<AcceptAssignmentButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _acceptAssignment,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.check_circle_outline),
      label: const Text('Accept Assignment'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ).animate(target: _isLoading ? 0 : 1)
     .scale(duration: const Duration(milliseconds: 300));
  }

  Future<void> _acceptAssignment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final hasConnection = connectivity != ConnectivityResult.none;

      if (hasConnection) {
        await _acceptAssignmentOnline();
      } else {
        await _acceptAssignmentOffline();
      }

      widget.onAcceptSuccess?.call();

      if (mounted) {
        AppSnackBar.show(
          context,
          message: hasConnection
              ? 'Assignment accepted successfully! You can now start the visit.'
              : 'Assignment accepted offline - will sync when online',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error accepting assignment: $e');

      widget.onAcceptError?.call();

      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Failed to accept assignment. Please try again.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptAssignmentOnline() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Update site entry to mark as accepted by this user
    await supabase
        .from('mmp_site_entries')
        .update({
          'accepted_by': userId,
          'accepted_at': DateTime.now().toIso8601String(),
          'status': 'Accepted',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', widget.siteEntryId)
        .eq('claimed_by', userId); // Ensure only the claimer can accept

    debugPrint('✅ Assignment accepted successfully for site: ${widget.siteEntryId}');
  }

  Future<void> _acceptAssignmentOffline() async {
    // Queue for offline sync
    await ref.read(acceptAssignmentOfflineProvider(widget.siteEntryId).future);
  }
}