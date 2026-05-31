import 'package:cloud_firestore/cloud_firestore.dart';

class GroupNoteModel {
  final String noteId;
  final String groupId;
  final String content;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  GroupNoteModel({
    required this.noteId,
    required this.groupId,
    required this.content,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory GroupNoteModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupNoteModel(
      noteId: id,
      groupId: map['groupId'] ?? '',
      content: map['content'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'content': content,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'content': content,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
