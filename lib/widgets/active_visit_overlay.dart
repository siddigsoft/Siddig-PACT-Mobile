import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../theme/app_design_system.dart';
import '../widgets/app_widgets.dart';
import '../providers/active_visit_provider.dart';
import '../services/storage_service.dart';

class ActiveVisitOverlay extends ConsumerStatefulWidget {
  const ActiveVisitOverlay({super.key});

  @override
  ConsumerState<ActiveVisitOverlay> createState() => _ActiveVisitOverlayState();
}

class _ActiveVisitOverlayState extends ConsumerState<ActiveVisitOverlay>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVisitState = ref.watch(activeVisitProvider);
    final hasActiveVisit = activeVisitState.hasActiveVisit;

    if (!hasActiveVisit) return const SizedBox.shrink();

    return Positioned(
          bottom: 100,
          left: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: _buildOverlay(activeVisitState),
          ),
        )
        .animate()
        .slideY(
          begin: 1.0,
          end: 0.0,
          duration: const Duration(milliseconds: 400),
        )
        .fadeIn(duration: const Duration(milliseconds: 300));
  }

  Widget _buildOverlay(ActiveVisitState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with site info and timer
          _buildHeader(state),

          // Expanded content
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            _buildExpandedContent(state),
          ],

          // Action buttons
          const SizedBox(height: 16),
          _buildActionButtons(state),
        ],
      ),
    );
  }

  Widget _buildHeader(ActiveVisitState state) {
    return Row(
      children: [
        // Site info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.visit!.siteName,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                state.visit!.siteCode,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.timer, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                state.formattedElapsedTime,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        // Expand/collapse button
        IconButton(
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
            if (_isExpanded) {
              _animationController.forward();
            } else {
              _animationController.reverse();
            }
          },
          icon: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(ActiveVisitState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location info
        if (state.currentLocation != null) ...[
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                'Tracking location',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Photos count
        Row(
          children: [
            Icon(Icons.photo_camera, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '${state.photos.length} photos taken',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        // Notes preview
        if (state.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            'Notes: ${state.notes}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(ActiveVisitState state) {
    return Row(
      children: [
        // Camera button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Complete button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showCompleteDialog(state),
            icon: const Icon(Icons.check_circle),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        // Upload photo to storage
        final storage = StorageService();
        final fileName = 'visit_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await image.readAsBytes();

        final photoUrl = await storage.uploadProfilePhotoBytes(
          'temp', // Temporary user ID for visit photos
          bytes,
          fileName,
        );

        // Add to active visit
        ref.read(activeVisitProvider.notifier).addPhoto(photoUrl);

        AppSnackBar.show(
          context,
          message: 'Photo added to visit',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Failed to take photo',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _showCompleteDialog(ActiveVisitState state) async {
    final notesController = TextEditingController(text: state.notes);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete Visit', style: AppTextStyles.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to complete this visit?',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
      await ref
          .read(activeVisitProvider.notifier)
          .completeVisit(
            notes: notesController.text.isNotEmpty
                ? notesController.text
                : null,
          );

      AppSnackBar.show(
        context,
        message: 'Visit completed successfully',
        type: SnackBarType.success,
      );
    }
  }
}
