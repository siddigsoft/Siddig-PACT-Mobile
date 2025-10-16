// lib/services/task_assignment_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site_visit.dart';
import '../algorithms/site_visit_assignment.dart';
import '../services/site_visit_service.dart';

enum TaskAssignmentResult {
  success,
  alreadyAssigned,
  networkError,
  permissionDenied,
}

class TaskAssignmentResponse {
  final TaskAssignmentResult result;
  final String? message;
  final SiteVisit? assignedTask;

  TaskAssignmentResponse({
    required this.result,
    this.message,
    this.assignedTask,
  });
}

class TaskAssignmentService {
  final SupabaseClient _supabase;
  final SiteVisitService _service;
  late final SiteVisitAssignment _assignmentAlgorithm;

  TaskAssignmentService(this._supabase, this._service) {
    _assignmentAlgorithm = SiteVisitAssignment(_supabase);
  }

  /// Accept a task assignment
  Future<TaskAssignmentResponse> acceptTask({
    required String taskId,
    required String userId,
  }) async {
    try {
      // Use the site_visit_assignment algorithm to attempt assignment
      final result = await _assignmentAlgorithm.attemptAssign(
        siteId: taskId,
        userId: userId,
      );

      if (result.success) {
        // Update local service
        await _service.updateSiteVisitStatus(taskId, 'assigned');

        // Get the updated task
        final updatedTask = await _service.getSiteVisitById(taskId);

        return TaskAssignmentResponse(
          result: TaskAssignmentResult.success,
          message: 'Task accepted successfully',
          assignedTask: updatedTask,
        );
      } else {
        if (result.error?.contains('already assigned') == true) {
          return TaskAssignmentResponse(
            result: TaskAssignmentResult.alreadyAssigned,
            message: 'This task has already been assigned to another operative',
          );
        } else {
          return TaskAssignmentResponse(
            result: TaskAssignmentResult.networkError,
            message: result.error ?? 'Failed to accept task',
          );
        }
      }
    } catch (e) {
      return TaskAssignmentResponse(
        result: TaskAssignmentResult.networkError,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Decline a task assignment
  Future<TaskAssignmentResponse> declineTask({
    required String taskId,
    required String userId,
  }) async {
    try {
      // For declining, we might want to record this in a separate table
      // or just remove it from the user's available tasks locally
      // The server might handle decline tracking differently

      // For now, we'll just mark it as declined locally
      // In a real implementation, you might want to call a server endpoint
      await _service.markTaskDeclined(taskId, userId);

      return TaskAssignmentResponse(
        result: TaskAssignmentResult.success,
        message: 'Task declined',
      );
    } catch (e) {
      return TaskAssignmentResponse(
        result: TaskAssignmentResult.networkError,
        message: 'Failed to decline task: ${e.toString()}',
      );
    }
  }

  /// Get tasks that have been accepted by the user and are in progress
  Future<List<SiteVisit>> getAcceptedTasks(String userId) async {
    return await _service.getAcceptedSiteVisits(userId);
  }

  /// Get tasks that have been assigned but not yet started
  Future<List<SiteVisit>> getAssignedPendingTasks(String userId) async {
    return await _service.getAssignedPendingSiteVisits(userId);
  }
}