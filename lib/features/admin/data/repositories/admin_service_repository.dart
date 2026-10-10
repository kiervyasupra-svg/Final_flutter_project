import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../customer/data/models/service_model.dart';

class AdminServiceRepository {
  AdminServiceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _services =>
      _firestore.collection('services');

  Stream<List<ServiceModel>> watchServices() {
    return _services.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ServiceModel.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.title.toLowerCase().compareTo(
                  b.title.toLowerCase(),
                )),
        );
  }

  Future<void> createService(ServiceModel service) async {
    await _services.add({
      ...service.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateService(ServiceModel service) async {
    await _services.doc(service.id).update({
      ...service.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setActive(String serviceId, bool isActive) async {
    await _services.doc(serviceId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveService(String serviceId) async {
    await _services.doc(serviceId).update({
      'isActive': false,
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restoreService(String serviceId) async {
    await _services.doc(serviceId).update({
      'isArchived': false,
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
