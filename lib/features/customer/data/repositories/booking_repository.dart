import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';
import '../models/reservation_model.dart';

class BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ServiceModel>> getActiveServices() {
    return _firestore.collection('services').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.id, doc.data()))
            .where((service) => service.isActive)
            .toList());
  }

  Future<void> createReservation(ReservationModel reservation) async {
    await _firestore.collection('reservations').doc().set(reservation.toMap());
  }

  Future<List<String>> getBookedTimeSlots(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final query = await _firestore
        .collection('reservations')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .where('status', whereIn: ['pending', 'approved', 'in_progress']).get();

    return query.docs.map((doc) => doc.data()['timeSlot'] as String).toList();
  }
}
