// lib/models/visit_report.dart

class VisitReport {
  final String siteId;
  final List<String> activities;
  final String? notes;
  final int durationMinutes;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final List<String> photoUrls;
  final DateTime submittedAt;

  VisitReport({
    required this.siteId,
    required this.activities,
    this.notes,
    required this.durationMinutes,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.photoUrls,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson({String? submittedBy}) {
    // Build comprehensive notes that includes all data
    final notesText = StringBuffer();
    if (notes != null && notes!.isNotEmpty) {
      notesText.writeln(notes);
    }
    notesText.writeln('\n--- Visit Details ---');
    notesText.writeln('Activities: ${activities.join(", ")}');
    notesText.writeln('Duration: $durationMinutes minutes');
    if (latitude != null && longitude != null) {
      notesText.writeln('Location: $latitude, $longitude (accuracy: ${accuracy ?? "N/A"}m)');
    }

    final reportData = <String, dynamic>{
      'site_visit_id': siteId,
      'notes': notesText.toString(),
      'submitted_at': submittedAt.toIso8601String(),
    };

    // Add optional fields if provided
    if (submittedBy != null) {
      reportData['submitted_by'] = submittedBy;
    }
    
    // Include additional fields - Supabase will ignore if columns don't exist
    reportData['activities'] = activities;
    reportData['duration_minutes'] = durationMinutes;
    if (latitude != null && longitude != null) {
      reportData['coordinates'] = {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      };
    }

    return reportData;
  }
}

