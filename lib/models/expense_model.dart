import 'package:cloud_firestore/cloud_firestore.dart';

class SplitDetail {
  final double owedAmount;
  final double? exactValue;
  final double? percentage;
  final double? shares;

  SplitDetail({
    required this.owedAmount,
    this.exactValue,
    this.percentage,
    this.shares,
  });

  factory SplitDetail.fromMap(Map<String, dynamic> map) {
    return SplitDetail(
      owedAmount: (map['owedAmount'] as num?)?.toDouble() ?? 0.0,
      exactValue: (map['exactValue'] as num?)?.toDouble(),
      percentage: (map['percentage'] as num?)?.toDouble(),
      shares: (map['shares'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'owedAmount': owedAmount,
      if (exactValue != null) 'exactValue': exactValue,
      if (percentage != null) 'percentage': percentage,
      if (shares != null) 'shares': shares,
    };
  }
}

class ExpenseModel {
  final String expenseId;
  final String? groupId;
  final String? friendId; // Used for direct friend-to-friend expenses
  final String description;
  final double amount;
  final String paidBy;
  final String splitType; // EQUAL, EXACT, PERCENT, SHARES
  final Map<String, SplitDetail> splits; // uid -> SplitDetail
  final bool isSettlement;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? deletedAt;

  ExpenseModel({
    required this.expenseId,
    this.groupId,
    this.friendId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splitType,
    required this.splits,
    this.isSettlement = false,
    required this.createdAt,
    required this.createdBy,
    this.deletedAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    final Map<String, dynamic> rawSplits = map['splits'] ?? {};
    final Map<String, SplitDetail> splits = {};
    rawSplits.forEach((key, value) {
      if (value is Map) {
        splits[key] = SplitDetail.fromMap(Map<String, dynamic>.from(value));
      }
    });

    return ExpenseModel(
      expenseId: id,
      groupId: map['groupId'],
      friendId: map['friendId'],
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidBy: map['paidBy'] ?? '',
      splitType: map['splitType'] ?? 'EQUAL',
      splits: splits,
      isSettlement: map['isSettlement'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
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
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'splitType': splitType,
      'splits': splits.map((key, value) => MapEntry(key, value.toMap())),
      'isSettlement': isSettlement,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'friendId': friendId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'splitType': splitType,
      'splits': splits.map((key, value) => MapEntry(key, value.toMap())),
      'isSettlement': isSettlement,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'deletedAt': deletedAt,
    };
  }
}
