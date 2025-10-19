class SiteVisit {
  final String id;
  final String siteName;
  final String siteCode;
  final String status;
  final String locality;
  final String state;
  final String activity;
  final String priority;
  final DateTime? dueDate;
  final String notes;
  final String mainActivity;
  final Map<String, dynamic>? location;
  double? get latitude {
    final lat = location?['latitude'];
    if (lat == null) return null;
    return lat is int ? lat.toDouble() : lat as double;
  }
  double? get longitude {
    final lng = location?['longitude'];
    if (lng == null) return null;
    return lng is int ? lng.toDouble() : lng as double;
  }
  String get locationString => location?['description'] as String? ?? '';
  final Map<String, dynamic>? fees;
  final Map<String, dynamic>? visitData;
  final String assignedTo;
  final String? assignedBy;
  final DateTime? assignedAt;
  final List<String>? attachments;
  final DateTime? completedAt;
  final int? rating;
  final String? mmpId;
  final DateTime createdAt;

  SiteVisit({
    required this.id,
    required this.siteName,
    required this.siteCode,
    required this.status,
    required this.locality,
    required this.state,
    required this.activity,
    required this.priority,
    this.dueDate,
    required this.notes,
    required this.mainActivity,
    this.location,
    this.fees,
    this.visitData,
    required this.assignedTo,
    this.assignedBy,
    this.assignedAt,
    this.attachments,
    this.completedAt,
    this.rating,
    this.mmpId,
    required this.createdAt,
  });

  factory SiteVisit.fromJson(Map<String, dynamic> json) {
    return SiteVisit(
      id: json['id'],
      siteName: json['site_name'],
      siteCode: json['site_code'],
      status: json['status'],
      locality: json['locality'],
      state: json['state'],
      activity: json['activity'],
      priority: json['priority'],
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      notes: json['notes'] ?? '',
      mainActivity: json['main_activity'] ?? '',
      location: json['location'],
      fees: json['fees'],
      visitData: json['visit_data'],
      assignedTo: json['assigned_to'],
      assignedBy: json['assigned_by'],
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'])
          : null,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      rating: json['rating'],
      mmpId: json['mmp_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_name': siteName,
      'site_code': siteCode,
      'status': status,
      'locality': locality,
      'state': state,
      'activity': activity,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'notes': notes,
      'main_activity': mainActivity,
      'location': location,
      'fees': fees,
      'visit_data': visitData,
      'assigned_to': assignedTo,
      'assigned_by': assignedBy,
      'assigned_at': assignedAt?.toIso8601String(),
      'attachments': attachments,
      'completed_at': completedAt?.toIso8601String(),
      'rating': rating,
      'mmp_id': mmpId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SiteVisit copyWith({
    String? id,
    String? siteName,
    String? siteCode,
    String? status,
    String? locality,
    String? state,
    String? activity,
    String? priority,
    DateTime? dueDate,
    String? notes,
    String? mainActivity,
    Map<String, dynamic>? location,
    Map<String, dynamic>? fees,
    Map<String, dynamic>? visitData,
    String? assignedTo,
    String? assignedBy,
    DateTime? assignedAt,
    List<String>? attachments,
    DateTime? completedAt,
    int? rating,
    String? mmpId,
    DateTime? createdAt,
  }) {
    return SiteVisit(
      id: id ?? this.id,
      siteName: siteName ?? this.siteName,
      siteCode: siteCode ?? this.siteCode,
      status: status ?? this.status,
      locality: locality ?? this.locality,
      state: state ?? this.state,
      activity: activity ?? this.activity,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      mainActivity: mainActivity ?? this.mainActivity,
      location: location ?? this.location,
      fees: fees ?? this.fees,
      visitData: visitData ?? this.visitData,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      attachments: attachments ?? this.attachments,
      completedAt: completedAt ?? this.completedAt,
      rating: rating ?? this.rating,
      mmpId: mmpId ?? this.mmpId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
