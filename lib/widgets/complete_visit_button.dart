import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_design_system.dart';
import '../widgets/app_widgets.dart';
import '../providers/offline_provider.dart';
import '../providers/active_visit_provider.dart';
import '../models/site_visit.dart';
import '../repositories/wallet_repository.dart';
import '../services/wallet_service.dart';

class CompleteVisitButton extends ConsumerStatefulWidget {
  final SiteVisit visit;
  final VoidCallback? onCompleteSuccess;
  final VoidCallback? onCompleteError;

  const CompleteVisitButton({
    super.key,
    required this.visit,
    this.onCompleteSuccess,
    this.onCompleteError,
  });

  @override
  ConsumerState<CompleteVisitButton> createState() => _CompleteVisitButtonState();
}

class _CompleteVisitButtonState extends ConsumerState<CompleteVisitButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final hasActiveVisit = ref.watch(hasActiveVisitProvider);
    final currentVisit = ref.watch(currentActiveVisitProvider);

    // Only show if this is the active visit
    if (!hasActiveVisit || currentVisit?.id != widget.visit.id) {
      return const SizedBox.shrink();
    }

    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _showCompleteDialog,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.check_circle),
      label: Text(_isLoading ? 'Completing...' : 'Complete Visit'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ).animate()
     .scale(duration: const Duration(milliseconds: 300));
  }

  Future<void> _showCompleteDialog() async {
    final activeVisitState = ref.read(activeVisitProvider);
    final notesController = TextEditingController(text: activeVisitState.notes);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Complete Visit',
          style: AppTextStyles.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Complete the visit for ${widget.visit.siteName}?',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Visit Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Text(
              'Photos taken: ${activeVisitState.photos.length}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _completeVisit(notesController.text);
    }
  }

  Future<void> _completeVisit(String? notes) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final activeVisitState = ref.read(activeVisitProvider);

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final hasConnection = connectivity != ConnectivityResult.none;

      if (hasConnection) {
        // Online complete
        await _completeVisitOnline(activeVisitState, notes);
      } else {
        // Offline complete
        await _completeVisitOffline(activeVisitState, notes);
      }

      // Stop active visit tracking
      await ref.read(activeVisitProvider.notifier).completeVisit(
        notes: notes,
        photos: activeVisitState.photos,
      );

      widget.onCompleteSuccess?.call();

      if (mounted) {
        AppSnackBar.show(
          context,
          message: hasConnection
              ? 'Visit completed successfully!'
              : 'Visit completed offline - will sync when online',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error completing visit: $e');

      widget.onCompleteError?.call();

      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Failed to complete visit: ${e.toString()}',
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

  Future<void> _completeVisitOnline(ActiveVisitState state, String? notes) async {
    final endLocation = state.currentLocation != null ? {
      'latitude': state.currentLocation!.latitude,
      'longitude': state.currentLocation!.longitude,
      'accuracy': state.currentLocation!.accuracy,
    } : null;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Update site visit in database
    await supabase
        .from('mmp_site_entries')
        .update({
          'status': 'completed',
          'visit_completed_at': DateTime.now().toIso8601String(),
          'visit_completed_by': userId,
          'additional_data': {
            'end_location': endLocation,
            'photos': state.photos,
            'notes': notes,
            'location_history': state.locationHistory.map((pos) => {
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'timestamp': pos.timestamp?.toIso8601String(),
            }).toList(),
          }
        })
        .eq('id', widget.visit.id);

    // Process wallet transaction if fees are configured
    await _processWalletTransaction(state, userId);
  }

  Future<void> _completeVisitOffline(ActiveVisitState state, String? notes) async {
    // Use offline provider to queue the completion
    await ref.read(completeSiteVisitOfflineProvider((
      visitId: widget.visit.id,
      notes: notes,
      photos: state.photos,
    )).future);
  }

  Future<void> _processWalletTransaction(ActiveVisitState state, String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final walletRepository = WalletRepository();
      final walletService = WalletService();

      // Get visit details to check for transport fee
      final visitData = await supabase
          .from('mmp_site_entries')
          .select('transport_fee')
          .eq('id', widget.visit.id)
          .single();

      final transportFee = _parseDouble(visitData['transport_fee']) ?? 0.0;

      // Recalculate enumerator fee based on current user classification
      final enumeratorFee = await walletService.calculateSiteVisitFeeFromClassification(
        userId: userId,
        complexityMultiplier: 1.0, // Default multiplier
      );

      final totalFee = enumeratorFee + transportFee;

      if (totalFee <= 0) {
        debugPrint('Total fee is zero or negative, skipping wallet transaction');
        return;
      }

      // Use wallet repository with deduplication checks
      await walletRepository.processVisitPayment(
        userId: userId,
        siteVisitId: widget.visit.id,
        enumeratorFee: enumeratorFee,
        transportFee: transportFee,
        referenceId: widget.visit.id, // Use visit ID as reference for dedup
      );

      debugPrint('Wallet transaction created successfully: Enumerator: $enumeratorFee, Transport: $transportFee, Total: $totalFee SDG');
    } catch (e) {
      debugPrint('Error processing wallet transaction: $e');
      // Don't fail the visit completion if wallet processing fails
      // This ensures the visit is marked complete even if wallet sync is delayed
    }
  }

  /// Helper to parse double values from dynamic JSON
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}