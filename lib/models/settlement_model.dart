import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementModel {
  final String settlementId;
  final String? groupId;
  final String? friendId;
  final String payerId;
  final String receiverId;
  final double amount;
  final String paymentMethod; // CASH, ONLINE
  final DateTime createdAt;
  final DateTime? deletedAt;

  SettlementModel({
    required this.settlementId,
    this.groupId,
    this.friendId,
    required this.payerId,
    required this.receiverId,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
    this.deletedAt,
  });

  factory SettlementModel.fromMap(Map<String, dynamic> map, String id) {
    return SettlementModel(
      settlementId: id,
      groupId: map['groupId'],
      friendId: map['friendId'],
      payerId: map['payerId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? 'CASH',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      deletedAt: map['deletedAt'] is Timestamp
          ? (map['deletedAt'] as Timestamp).toDate()
          : map['deletedAt'] != null
              ? DateTime.tryParse(map['deletedAt'].toString())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'friendId': friendId,
      'payerId': payerId,
      'receiverId': receiverId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'friendId': friendId,
      'payerId': payerId,
      'receiverId': receiverId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedAt': deletedAt,
    };
  }
}
