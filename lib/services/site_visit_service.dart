import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site_visit.dart';

class SiteVisitService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
}
