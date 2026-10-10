import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationModel {
  final String id;
  final String userId;
  final String userName;
  final String serviceId;
  final String serviceTitle;
  final String vehicleType;
  final DateTime date;
  final String timeSlot;
  final String status;
  final double reservationFee;
  final double totalAmount;
  final DateTime createdAt;

  ReservationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.serviceId,
    required this.serviceTitle,
    required this.vehicleType,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.reservationFee,
    required this.totalAmount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'vehicleType': vehicleType,
      'date': Timestamp.fromDate(date),
      'timeSlot': timeSlot,
      'status': status,
      'reservationFee': reservationFee,
      'totalAmount': totalAmount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
