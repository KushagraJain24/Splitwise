import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMemberDetail {
  final String displayName;
  final String email;
  final bool isPlaceholder;

  GroupMemberDetail({
    required this.displayName,
    required this.email,
    required this.isPlaceholder,
  });

  factory GroupMemberDetail.fromMap(Map<String, dynamic> map) {
    return GroupMemberDetail(
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      isPlaceholder: map['isPlaceholder'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'isPlaceholder': isPlaceholder,
    };
  }
}

class GroupModel {
  final String groupId;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final List<String> members;
  final Map<String, GroupMemberDetail> memberDetails;
  final String type; // TRIP, FAMILY, SELF, NO_EXPENSE
  final DateTime? deletedAt;

  GroupModel({
    required this.groupId,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.memberDetails,
    this.type = 'TRIP',
    this.deletedAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    final Map<String, dynamic> rawDetails = map['memberDetails'] ?? {};
    final Map<String, GroupMemberDetail> details = {};
    rawDetails.forEach((key, value) {
      if (value is Map) {
        details[key] = GroupMemberDetail.fromMap(Map<String, dynamic>.from(value));
      }
    });

    return GroupModel(
      groupId: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      members: List<String>.from(map['members'] ?? []),
      memberDetails: details,
      type: map['type'] ?? 'TRIP',
      deletedAt: map['deletedAt'] is Timestamp
          ? (map['deletedAt'] as Timestamp).toDate()
          : map['deletedAt'] != null
              ? DateTime.tryParse(map['deletedAt'].toString())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'members': members,
      'memberDetails': memberDetails.map((key, value) => MapEntry(key, value.toMap())),
      'type': type,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'members': members,
      'memberDetails': memberDetails.map((key, value) => MapEntry(key, value.toMap())),
      'type': type,
      'deletedAt': deletedAt != null ? FieldValue.serverTimestamp() : null,
    };
  }
}
