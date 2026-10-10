import 'package:flutter/material.dart';
import '../../../customer/data/models/reservation_model.dart';
import '../../../customer/data/models/wallet_transaction_model.dart';
import '../../data/repositories/admin_repository.dart';

class AdminController extends ChangeNotifier {
  final AdminRepository _repo = AdminRepository();

  List<ReservationModel> _reservations = [];
  List<WalletTransactionModel> _pendingTopUps = [];
  bool _isLoading = false;

  List<ReservationModel> get reservations => _reservations;
  List<WalletTransactionModel> get pendingTopUps => _pendingTopUps;
  bool get isLoading => _isLoading;

  AdminController() {
    _listenData();
  }

  void _listenData() {
    _repo.getAllReservations().listen((resList) {
      _reservations = resList;
      notifyListeners();
    });

    _repo.getPendingTopUps().listen((topUpList) {
      _pendingTopUps = topUpList;
      notifyListeners();
    });
  }

  Future<void> updateReservationStatus(
      String resId, String userId, String status) async {
    _isLoading = true;
    notifyListeners();
    await _repo.updateReservationStatus(
        reservationId: resId, userId: userId, newStatus: status);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> approveTopUp(String txId, String userId, double amount) async {
    _isLoading = true;
    notifyListeners();
    await _repo.approveTopUp(
        transactionId: txId, userId: userId, amount: amount);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> rejectTopUp(String txId) async {
    _isLoading = true;
    notifyListeners();
    await _repo.rejectTopUp(txId);
    _isLoading = false;
    notifyListeners();
  }
}
