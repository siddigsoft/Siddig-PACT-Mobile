enum IncidentType {
  harassment,
  theft,
  accident,
  medicalEmergency,
  naturalDisaster,
  other,
}

class IncidentReport {
  final String id;
  final DateTime date;
  final IncidentType type;
  final String description;
  final String location;
  final List<String>? witnesses;
  final bool requiresImmediate;
  final String? actionTaken;
  final List<String>? mediaUrls; // For photos or videos
  final String reportedBy;

  IncidentReport({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.location,
    this.witnesses,
    required this.requiresImmediate,
    this.actionTaken,
    this.mediaUrls,
    required this.reportedBy,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'type': type.toString().split('.').last,
    'description': description,
    'location': location,
    'witnesses': witnesses,
    'requiresImmediate': requiresImmediate,
    'actionTaken': actionTaken,
    'mediaUrls': mediaUrls,
    'reportedBy': reportedBy,
  };

  factory IncidentReport.fromJson(Map<String, dynamic> json) => IncidentReport(
    id: json['id'],
    date: DateTime.parse(json['date']),
    type: IncidentType.values.firstWhere(
      (e) => e.toString().split('.').last == json['type'],
    ),
    description: json['description'],
    location: json['location'],
    witnesses: json['witnesses'] != null
        ? List<String>.from(json['witnesses'])
        : null,
    requiresImmediate: json['requiresImmediate'],
    actionTaken: json['actionTaken'],
    mediaUrls: json['mediaUrls'] != null
        ? List<String>.from(json['mediaUrls'])
        : null,
    reportedBy: json['reportedBy'],
  );
}
