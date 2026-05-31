import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String activityId;
  final String? groupId;
  final String? friendId;
  final String activityType; // 'group_create', 'member_add', 'expense_add', 'settlement', 'expense_delete'
  final List<String> userIds; // Users who see this activity in their feed
  final String actorId; // Person who performed the action
  final String? targetId; // Person who is the target (e.g. member added)
  final Map<String, dynamic> metadata; // Extra info like groupName, expenseDescription, amount, etc.
  final DateTime createdAt;

  ActivityModel({
    required this.activityId,
    this.groupId,
    this.friendId,
    required this.activityType,
    required this.userIds,
    required this.actorId,
    this.targetId,
    required this.metadata,
    required this.createdAt,
  });

  factory ActivityModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return ActivityModel(
      activityId: docId ?? map['activityId'] ?? '',
      groupId: map['groupId'],
      friendId: map['friendId'],
      activityType: map['activityType'] ?? '',
      userIds: List<String>.from(map['userIds'] ?? []),
      actorId: map['actorId'] ?? '',
      targetId: map['targetId'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'groupId': groupId,
      'friendId': friendId,
      'activityType': activityType,
      'userIds': userIds,
      'actorId': actorId,
      'targetId': targetId,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'friendId': friendId,
      'activityType': activityType,
      'userIds': userIds,
      'actorId': actorId,
      'targetId': targetId,
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
