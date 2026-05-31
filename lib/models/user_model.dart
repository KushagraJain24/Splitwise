import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? phone;
  final bool isPlaceholder;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required String email,
    required this.displayName,
    this.photoUrl,
    String? phone,
    this.isPlaceholder = false,
    required this.createdAt,
  })  : this.email = email.trim().toLowerCase(),
        this.phone = phone != null && phone.trim().replaceAll(RegExp(r'\D'), '').isNotEmpty
            ? phone.trim().replaceAll(RegExp(r'\D'), '')
            : null;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      phone: map['phone'],
      isPlaceholder: map['isPlaceholder'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phone': phone,
      'isPlaceholder': isPlaceholder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // To serialize for Firestore specifically
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phone': phone,
      'isPlaceholder': isPlaceholder,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phone,
    bool? isPlaceholder,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
