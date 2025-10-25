import 'chat_participant.dart';

class Chat {
  String id;
  String name;
  String type; // 'private', 'group', 'state-group'
  bool isGroup;
  String? createdBy;
  String? stateId;
  String? relatedEntityId;
  String? relatedEntityType; // 'mmpFile', 'siteVisit', 'project'
  DateTime createdAt;
  DateTime updatedAt;
  String? pairKey; // For private chats, sorted user IDs like "user1-user2"
  List<ChatParticipant> participants;

  Chat({
    required this.id,
    required this.name,
    required this.type,
    required this.isGroup,
    this.createdBy,
    this.stateId,
    this.relatedEntityId,
    this.relatedEntityType,
    required this.createdAt,
    required this.updatedAt,
    this.pairKey,
    this.participants = const [],
  });

  String get chatType => type;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'is_group': isGroup,
      'created_by': createdBy,
      'state_id': stateId,
      'related_entity_id': relatedEntityId,
      'related_entity_type': relatedEntityType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'pair_key': pairKey,
    };
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      isGroup: json['is_group'] ?? false,
      createdBy: json['created_by'],
      stateId: json['state_id'],
      relatedEntityId: json['related_entity_id'],
      relatedEntityType: json['related_entity_type'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      pairKey: json['pair_key'],
      participants: [], // Will be populated separately
    );
  }
}
