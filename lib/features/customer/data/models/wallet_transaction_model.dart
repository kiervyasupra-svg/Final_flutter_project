import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'topup', 'payment', or 'refund'
  final String proofOfPaymentUrl;
  final String status; // 'pending', 'approved', or 'rejected'
  final DateTime createdAt;

  WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.proofOfPaymentUrl = '',
    required this.status,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return WalletTransactionModel(
      id: id,
      userId: map['userId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] ?? 'topup',
      proofOfPaymentUrl: map['proofOfPaymentUrl'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type,
      'proofOfPaymentUrl': proofOfPaymentUrl,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
