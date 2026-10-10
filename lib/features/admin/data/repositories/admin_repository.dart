import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../customer/data/models/reservation_model.dart';
import '../../../customer/data/models/wallet_transaction_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all reservations
  Stream<List<ReservationModel>> getAllReservations() {
    return _firestore
        .collection('reservations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReservationModel(
                  id: doc.id,
                  userId: doc.data()['userId'] ?? '',
                  userName: doc.data()['userName'] ?? 'Customer',
                  serviceId: doc.data()['serviceId'] ?? '',
                  serviceTitle: doc.data()['serviceTitle'] ?? '',
                  vehicleType: doc.data()['vehicleType'] ?? '',
                  date: (doc.data()['date'] as Timestamp).toDate(),
                  timeSlot: doc.data()['timeSlot'] ?? '',
                  status: doc.data()['status'] ?? 'pending',
                  reservationFee:
                      (doc.data()['reservationFee'] as num?)?.toDouble() ?? 0.0,
                  totalAmount:
                      (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0,
                  createdAt: (doc.data()['createdAt'] as Timestamp).toDate(),
                ))
            .toList());
  }

  // Update reservation status (approved, completed, cancelled) & reward points upon completion
  Future<void> updateReservationStatus({
    required String reservationId,
    required String userId,
    required String newStatus,
    double servicePrice = 0.0,
  }) async {
    final batch = _firestore.batch();
    final resRef = _firestore.collection('reservations').doc(reservationId);

    batch.update(resRef, {'status': newStatus});

    // Award 10 reward points for completed service
    if (newStatus == 'completed') {
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'rewardPoints': FieldValue.increment(10),
      });
    }

    await batch.commit();
  }

  // Stream pending wallet top-up requests
  Stream<List<WalletTransactionModel>> getPendingTopUps() {
    return _firestore
        .collection('wallet_transactions')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransactionModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Approve top-up: Credit amount to customer's wallet balance
  Future<void> approveTopUp({
    required String transactionId,
    required String userId,
    required double amount,
  }) async {
    final batch = _firestore.batch();
    final txRef =
        _firestore.collection('wallet_transactions').doc(transactionId);
    final userRef = _firestore.collection('users').doc(userId);

    batch.update(txRef, {'status': 'approved'});
    batch.update(userRef, {
      'walletBalance': FieldValue.increment(amount),
    });

    await batch.commit();
  }

  // Reject top-up request
  Future<void> rejectTopUp(String transactionId) async {
    await _firestore
        .collection('wallet_transactions')
        .doc(transactionId)
        .update({'status': 'rejected'});
  }
}
