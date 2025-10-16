import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site_visit.dart';

class SiteVisitService {
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseClient get supabase => _supabase;

  Future<List<Map<String, dynamic>>> getAssignedSiteVisits(
    String userId,
  ) async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('assigned_to', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getSiteVisitDetails(String visitId) async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('id', visitId)
        .single();

    return response;
  }

  Future<void> updateSiteVisitStatus(String visitId, String status) async {
    await _supabase
        .from('site_visits')
        .update({'status': status})
        .eq('id', visitId);
  }

  Future<void> updateSiteVisit(SiteVisit visit) async {
    await _supabase
        .from('site_visits')
        .update(visit.toJson())
        .eq('id', visit.id);
  }

  Future<List<SiteVisit>> getAvailableSiteVisits() async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('status', 'available')
        .order('created_at', ascending: false);

    return response.map((json) => SiteVisit.fromJson(json)).toList();
  }

  Future<List<SiteVisit>> getAcceptedSiteVisits(String userId) async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('assigned_to', userId)
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    return response.map((json) => SiteVisit.fromJson(json)).toList();
  }

  Future<List<SiteVisit>> getAssignedPendingSiteVisits(String userId) async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('assigned_to', userId)
        .eq('status', 'assigned')
        .order('created_at', ascending: false);

    return response.map((json) => SiteVisit.fromJson(json)).toList();
  }

  Future<SiteVisit?> getSiteVisitById(String id) async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('id', id)
        .single();

    return SiteVisit.fromJson(response);
  }

  Future<void> markTaskDeclined(String taskId, String userId) async {
    // This could be implemented as a separate table for declined tasks
    // For now, we'll just log it locally or update a declined status
    await _supabase
        .from('site_visits')
        .update({
          'status': 'declined',
          'declined_by': userId,
          'declined_at': DateTime.now().toIso8601String(),
        })
        .eq('id', taskId);
  }
}
