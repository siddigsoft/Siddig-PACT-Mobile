import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cost_submission_models.dart';
import '../repositories/cost_submission_repository.dart';
import '../services/cost_submission_service.dart';

// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Cost submission repository provider
final costSubmissionRepositoryProvider = Provider<CostSubmissionRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CostSubmissionRepository(supabase);
});

// Cost submission service provider
final costSubmissionServiceProvider = Provider<CostSubmissionService>((ref) {
  return CostSubmissionService();
});

// Current user ID provider (assumes user is authenticated)
final currentUserIdProvider = Provider<String>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id ?? '';
});

// Stream provider for user's cost submissions (real-time)
final userCostSubmissionsStreamProvider = StreamProvider.autoDispose<List<CostSubmission>>((ref) {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId.isEmpty) {
    return Stream.value([]);
  }
  
  return repository.watchUserCostSubmissions(userId);
});

// Future provider for user's cost submissions
final userCostSubmissionsProvider = FutureProvider.autoDispose<List<CostSubmission>>((ref) async {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId.isEmpty) {
    return [];
  }
  
  return repository.getUserCostSubmissions(userId);
});

// Provider for cost submissions filtered by status
final costSubmissionsByStatusProvider = FutureProvider.autoDispose.family<List<CostSubmission>, CostSubmissionStatus?>((ref, status) async {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId.isEmpty) {
    return [];
  }
  
  if (status == null) {
    return repository.getUserCostSubmissions(userId);
  }
  
  return repository.getCostSubmissionsByStatus(userId, status);
});

// Provider for single cost submission by ID
final costSubmissionByIdProvider = FutureProvider.autoDispose.family<CostSubmission?, String>((ref, id) async {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  return repository.getCostSubmissionById(id);
});

// Provider for cost submission statistics
final costSubmissionStatsProvider = FutureProvider.autoDispose<CostSubmissionStats>((ref) async {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId.isEmpty) {
    return CostSubmissionStats();
  }
  
  return repository.getCostSubmissionStats(userId);
});

// State provider for selected status filter
final selectedStatusFilterProvider = StateProvider.autoDispose<CostSubmissionStatus?>((ref) => null);

// State provider for search query
final costSubmissionSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// Provider for filtered and searched cost submissions
final filteredCostSubmissionsProvider = FutureProvider.autoDispose<List<CostSubmission>>((ref) async {
  final submissions = await ref.watch(userCostSubmissionsProvider.future);
  final statusFilter = ref.watch(selectedStatusFilterProvider);
  final searchQuery = ref.watch(costSubmissionSearchQueryProvider);
  final service = ref.watch(costSubmissionServiceProvider);
  
  var filtered = submissions;
  
  // Apply status filter
  if (statusFilter != null) {
    filtered = service.filterByStatus(filtered, statusFilter);
  }
  
  // Apply search filter
  if (searchQuery.isNotEmpty) {
    filtered = filtered.where((submission) {
      final lowerQuery = searchQuery.toLowerCase();
      return submission.siteVisitId.toLowerCase().contains(lowerQuery) ||
             submission.submissionNotes?.toLowerCase().contains(lowerQuery) == true ||
             submission.transportationDetails?.toLowerCase().contains(lowerQuery) == true ||
             submission.accommodationDetails?.toLowerCase().contains(lowerQuery) == true;
    }).toList();
  }
  
  return filtered;
});

// State notifier for creating cost submission
class CreateCostSubmissionNotifier extends StateNotifier<AsyncValue<CostSubmission?>> {
  CreateCostSubmissionNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> create(CreateCostSubmissionRequest request) async {
    state = const AsyncValue.loading();
    
    try {
      final repository = ref.read(costSubmissionRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);
      
      if (userId.isEmpty) {
        throw CostSubmissionException('User not authenticated');
      }
      
      final submission = await repository.createCostSubmission(request, userId);
      state = AsyncValue.data(submission);
      
      // Invalidate related providers
      ref.invalidate(userCostSubmissionsProvider);
      ref.invalidate(userCostSubmissionsStreamProvider);
      ref.invalidate(costSubmissionStatsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final createCostSubmissionProvider = StateNotifierProvider.autoDispose<CreateCostSubmissionNotifier, AsyncValue<CostSubmission?>>((ref) {
  return CreateCostSubmissionNotifier(ref);
});

// State notifier for updating cost submission
class UpdateCostSubmissionNotifier extends StateNotifier<AsyncValue<CostSubmission?>> {
  UpdateCostSubmissionNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> update(String id, UpdateCostSubmissionRequest request) async {
    state = const AsyncValue.loading();
    
    try {
      final repository = ref.read(costSubmissionRepositoryProvider);
      final submission = await repository.updateCostSubmission(id, request);
      state = AsyncValue.data(submission);
      
      // Invalidate related providers
      ref.invalidate(userCostSubmissionsProvider);
      ref.invalidate(userCostSubmissionsStreamProvider);
      ref.invalidate(costSubmissionStatsProvider);
      ref.invalidate(costSubmissionByIdProvider(id));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final updateCostSubmissionProvider = StateNotifierProvider.autoDispose<UpdateCostSubmissionNotifier, AsyncValue<CostSubmission?>>((ref) {
  return UpdateCostSubmissionNotifier(ref);
});

// State notifier for cancelling cost submission
class CancelCostSubmissionNotifier extends StateNotifier<AsyncValue<CostSubmission?>> {
  CancelCostSubmissionNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> cancel(String id) async {
    state = const AsyncValue.loading();
    
    try {
      final repository = ref.read(costSubmissionRepositoryProvider);
      final submission = await repository.cancelCostSubmission(id);
      state = AsyncValue.data(submission);
      
      // Invalidate related providers
      ref.invalidate(userCostSubmissionsProvider);
      ref.invalidate(userCostSubmissionsStreamProvider);
      ref.invalidate(costSubmissionStatsProvider);
      ref.invalidate(costSubmissionByIdProvider(id));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final cancelCostSubmissionProvider = StateNotifierProvider.autoDispose<CancelCostSubmissionNotifier, AsyncValue<CostSubmission?>>((ref) {
  return CancelCostSubmissionNotifier(ref);
});

// Provider for pending cost submissions count
final pendingCostSubmissionsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final stats = await ref.watch(costSubmissionStatsProvider.future);
  return stats.pendingCount;
});

// Provider for total pending amount
final totalPendingAmountProvider = FutureProvider.autoDispose<int>((ref) async {
  final stats = await ref.watch(costSubmissionStatsProvider.future);
  return stats.totalPendingAmountCents;
});

// Provider for total approved amount
final totalApprovedAmountProvider = FutureProvider.autoDispose<int>((ref) async {
  final stats = await ref.watch(costSubmissionStatsProvider.future);
  return stats.totalApprovedAmountCents;
});

// Provider for total paid amount
final totalPaidAmountProvider = FutureProvider.autoDispose<int>((ref) async {
  final stats = await ref.watch(costSubmissionStatsProvider.future);
  return stats.totalPaidAmountCents;
});

// ============================================================================
// NEW PROVIDERS FOR IMPROVEMENTS
// ============================================================================

// Stream provider for pending approvals (admin/finance only)
final pendingApprovalsStreamProvider = StreamProvider.autoDispose<List<CostSubmission>>((ref) {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  return repository.watchPendingApprovals();
});

// Future provider for pending approvals
final pendingApprovalsProvider = FutureProvider.autoDispose<List<CostSubmission>>((ref) async {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  return repository.getPendingApprovals();
});

// Provider for revision requested submissions
final revisionRequestedProvider = FutureProvider.autoDispose<List<CostSubmission>>((ref) async {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId.isEmpty) {
    return [];
  }
  
  return repository.getRevisionRequested(userId);
});

// Provider for approval history of a submission
final approvalHistoryProvider = FutureProvider.autoDispose.family<List<CostApprovalHistory>, String>((ref, submissionId) async {
  final repository = ref.watch(costSubmissionRepositoryProvider);
  return repository.getApprovalHistory(submissionId);
});

// Review cost submission notifier
class ReviewCostSubmissionNotifier extends StateNotifier<AsyncValue<CostSubmission?>> {
  final Ref ref;

  ReviewCostSubmissionNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> reviewSubmission(ReviewCostSubmissionRequest request) async {
    state = const AsyncValue.loading();
    
    try {
      final repository = ref.read(costSubmissionRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);
      
      if (userId.isEmpty) {
        throw CostSubmissionException('User not authenticated');
      }
      
      final submission = await repository.reviewCostSubmission(request, userId);
      state = AsyncValue.data(submission);
      
      // Invalidate related providers
      ref.invalidate(userCostSubmissionsProvider);
      ref.invalidate(userCostSubmissionsStreamProvider);
      ref.invalidate(pendingApprovalsProvider);
      ref.invalidate(pendingApprovalsStreamProvider);
      ref.invalidate(costSubmissionStatsProvider);
      ref.invalidate(costSubmissionByIdProvider(request.submissionId));
      ref.invalidate(approvalHistoryProvider(request.submissionId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> approveSubmission(String submissionId, String? notes) async {
    await reviewSubmission(ReviewCostSubmissionRequest(
      submissionId: submissionId,
      action: ReviewAction.approve,
      approvalNotes: notes,
      reviewerNotes: notes,
    ));
  }

  Future<void> rejectSubmission(String submissionId, String? notes) async {
    await reviewSubmission(ReviewCostSubmissionRequest(
      submissionId: submissionId,
      action: ReviewAction.reject,
      reviewerNotes: notes,
    ));
  }

  Future<void> requestRevision(String submissionId, String revisionNotes) async {
    await reviewSubmission(ReviewCostSubmissionRequest(
      submissionId: submissionId,
      action: ReviewAction.requestRevision,
      revisionNotes: revisionNotes,
      reviewerNotes: revisionNotes,
    ));
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final reviewCostSubmissionProvider = StateNotifierProvider.autoDispose<ReviewCostSubmissionNotifier, AsyncValue<CostSubmission?>>((ref) {
  return ReviewCostSubmissionNotifier(ref);
});
