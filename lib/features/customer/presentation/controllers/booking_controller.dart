import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/service_schedule.dart';
import '../../data/models/service_model.dart';

class BookingController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ServiceModel> _services = [];
  List<String> _bookedSlots = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _servicesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _bookedSlotsSubscription;
  int _bookedSlotsRequestId = 0;
  String? _bookedSlotsErrorMessage;

  List<ServiceModel> get services => _services;
  List<String> get bookedSlots => _bookedSlots;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get bookedSlotsErrorMessage => _bookedSlotsErrorMessage;

  Future<void> fetchServices() async {
    if (_servicesSubscription != null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _servicesSubscription =
        _firestore.collection('services').snapshots().listen(
      (snapshot) {
        _services = snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.id, doc.data()))
            .where((service) => service.isActive && !service.isArchived)
            .toList();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        _errorMessage = 'Unable to load services right now.';
        _isLoading = false;
        debugPrint('Error watching services: $error');
        notifyListeners();
      },
    );
  }

  Future<void> fetchBookedSlots(
    DateTime date, {
    int requestedDurationMinutes = 60,
  }) async {
    final requestId = ++_bookedSlotsRequestId;
    _isLoading = true;
    _bookedSlots = [];
    _bookedSlotsErrorMessage = null;
    notifyListeners();

    await _bookedSlotsSubscription?.cancel();
    if (requestId != _bookedSlotsRequestId) return;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    _bookedSlotsSubscription = _firestore
        .collection('reservations')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .listen(
      (snapshot) {
        if (requestId != _bookedSlotsRequestId) return;
        final reservations = snapshot.docs
            .map((doc) => doc.data())
            .where(
              (reservation) =>
                  const {'PENDING', 'APPROVED', 'IN_PROGRESS'}.contains(
                (reservation['status'] ?? '').toString().toUpperCase(),
              ),
            )
            .toList();
        _bookedSlots = ServiceSchedule.timeSlots.where((candidate) {
          return reservations.any((reservation) {
            final existingSlot = (reservation['timeSlot'] ?? '').toString();
            if (existingSlot.isEmpty) return false;
            return ServiceSchedule.intervalsOverlap(
              firstTimeSlot: candidate,
              firstDurationMinutes: requestedDurationMinutes,
              secondTimeSlot: existingSlot,
              secondDurationMinutes:
                  (reservation['durationMinutes'] as num?)?.toInt() ?? 60,
            );
          });
        }).toList();
        _bookedSlotsErrorMessage = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (requestId != _bookedSlotsRequestId) return;
        debugPrint('Error watching booked slots: $error');
        _bookedSlots = List<String>.from(ServiceSchedule.timeSlots);
        _bookedSlotsErrorMessage =
            'Unable to load available time slots. Please try again.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> createPaidReservation({
    required String userId,
    required ServiceModel service,
    required DateTime selectedDate,
    required String selectedTimeSlot,
    required String vehicleType,
    required String location,
    required double amountPaid,
  }) async {
    if (ServiceSchedule.isTimeSlotInPast(selectedDate, selectedTimeSlot)) {
      throw Exception(
        'This time slot has already passed. Please choose another time.',
      );
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sameDayStart = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final sameDayEnd = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        23,
        59,
        59,
      );

      final reservationQuery = _firestore
          .collection('reservations')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sameDayStart),
          )
          .where(
            'date',
            isLessThanOrEqualTo: Timestamp.fromDate(sameDayEnd),
          );
      final reservationSnapshot = await reservationQuery.get();

      await _firestore.runTransaction((transaction) async {
        if (ServiceSchedule.isTimeSlotInPast(
          selectedDate,
          selectedTimeSlot,
        )) {
          throw Exception(
            'This time slot has already passed. Please choose another time.',
          );
        }

        final serviceRef = _firestore.collection('services').doc(service.id);
        final userRef = _firestore.collection('users').doc(userId);
        final serviceSnapshot = await transaction.get(serviceRef);
        if (!serviceSnapshot.exists) {
          throw Exception('This service is no longer available.');
        }
        final latestService = ServiceModel.fromMap(
          service.id,
          serviceSnapshot.data()!,
        );
        if (!latestService.isActive || latestService.isArchived) {
          throw Exception('This service is no longer available for booking.');
        }
        if (!latestService.vehicleTypes.contains(vehicleType)) {
          throw Exception(
            'This service is not available for the selected vehicle type.',
          );
        }
        final hasConflict = reservationSnapshot.docs.any((doc) {
          final reservation = doc.data();
          final status = (reservation['status'] ?? '').toString().toUpperCase();
          if (!const {'PENDING', 'APPROVED', 'IN_PROGRESS'}.contains(status)) {
            return false;
          }
          return ServiceSchedule.intervalsOverlap(
            firstTimeSlot: selectedTimeSlot,
            firstDurationMinutes: latestService.durationMinutes,
            secondTimeSlot: (reservation['timeSlot'] ?? '').toString(),
            secondDurationMinutes:
                (reservation['durationMinutes'] as num?)?.toInt() ?? 60,
          );
        });
        if (hasConflict) {
          throw Exception(
            'This service overlaps another reservation. Please choose another time.',
          );
        }
        final servicePrice = latestService.priceForVehicle(vehicleType);
        final requiredPayment = servicePrice;
        if (!requiredPayment.isFinite ||
            requiredPayment <= 0 ||
            (amountPaid - requiredPayment).abs() > 0.01) {
          throw Exception(
            'The service price changed. Please review the updated total and try again.',
          );
        }

        final userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception('User account not found.');
        }

        final double currentBalance =
            (userSnapshot.data()?['walletBalance'] ?? 0.0).toDouble();

        if (currentBalance < requiredPayment) {
          throw Exception('Insufficient wallet balance for full payment.');
        }

        transaction.update(userRef, {
          'walletBalance': currentBalance - requiredPayment,
        });

        final reservationRef = _firestore.collection('reservations').doc();
        transaction.set(reservationRef, {
          'id': reservationRef.id,
          'userId': userId,
          'serviceId': service.id,
          'serviceTitle': latestService.title,
          'price': servicePrice,
          'durationMinutes': latestService.durationMinutes,
          'amountPaid': requiredPayment,
          'remainingBalance': 0.0,
          'loyaltyPointsReward': latestService.loyaltyPoints,
          'pointsAwarded': false,
          'paymentStatus': 'PAID',
          'status': 'PENDING',
          'date': Timestamp.fromDate(selectedDate),
          'timeSlot': selectedTimeSlot,
          'vehicleType': vehicleType,
          'location': location,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> isSlotAvailableForDate({
    required DateTime date,
    required String timeSlot,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('reservations')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    return !snapshot.docs.any((doc) {
      final reservation = doc.data();
      final status = (reservation['status'] ?? '').toString().toUpperCase();
      final reservedTimeSlot = (reservation['timeSlot'] ?? '').toString();
      return status == 'APPROVED' && reservedTimeSlot == timeSlot;
    });
  }

  @override
  void dispose() {
    _bookedSlotsRequestId++;
    _servicesSubscription?.cancel();
    _bookedSlotsSubscription?.cancel();
    super.dispose();
  }
}
