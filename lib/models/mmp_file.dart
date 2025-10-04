class MMPFile {
  final String id;
  final String? name;
  final DateTime? uploadedAt;
  final String? status;
  final int? entries;
  final int? processedEntries;
  final String? mmpId;
  final Map<String, dynamic>? version;
  final Map<String, dynamic>? siteEntries;
  final Map<String, dynamic>? workflow;
  final String? projectId;
  final String? filePath;
  final String? originalFilename;
  final String? fileUrl;
  final DateTime createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  MMPFile({
    required this.id,
    this.name,
    this.uploadedAt,
    this.status,
    this.entries,
    this.processedEntries,
    this.mmpId,
    this.version,
    this.siteEntries,
    this.workflow,
    this.projectId,
    this.filePath,
    this.originalFilename,
    this.fileUrl,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.verifiedBy,
    this.verifiedAt,
  });

  factory MMPFile.fromJson(Map<String, dynamic> json) {
    return MMPFile(
      id: json['id'],
      name: json['name'],
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : null,
      status: json['status'],
      entries: json['entries'],
      processedEntries: json['processed_entries'],
      mmpId: json['mmp_id'],
      version: json['version'],
      siteEntries: json['site_entries'],
      workflow: json['workflow'],
      projectId: json['project_id'],
      filePath: json['file_path'],
      originalFilename: json['original_filename'],
      fileUrl: json['file_url'],
      createdAt: DateTime.parse(json['created_at']),
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      verifiedBy: json['verified_by'],
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'status': status,
      'entries': entries,
      'processed_entries': processedEntries,
      'mmp_id': mmpId,
      'version': version,
      'site_entries': siteEntries,
      'workflow': workflow,
      'project_id': projectId,
      'file_path': filePath,
      'original_filename': originalFilename,
      'file_url': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
    };
  }
}
