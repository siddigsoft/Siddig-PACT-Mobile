class Task {
  String id;
  String title;
  String description;
  String status; // 'pending', 'in_progress', 'completed'
  DateTime dueDate;
  String assignedTo;
  String priority; // 'low', 'medium', 'high'
  Map<String, dynamic>? metadata;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.assignedTo,
    required this.priority,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'dueDate': dueDate.toIso8601String(),
      'assignedTo': assignedTo,
      'priority': priority,
      'metadata': metadata,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      dueDate: DateTime.parse(json['dueDate']),
      assignedTo: json['assignedTo'],
      priority: json['priority'],
      metadata: json['metadata'],
    );
  }
}