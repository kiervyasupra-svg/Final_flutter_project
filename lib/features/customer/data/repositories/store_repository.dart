import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/product_model.dart';
import '../models/wallet_transaction_model.dart';

class StoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<ProductModel>> getProducts() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCustomerOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<String> placeOrder({
    required String userId,
    required String customerName,
    required String customerEmail,
    required Map<ProductModel, int> items,
    required String paymentMethod,
  }) async {
    if (items.isEmpty || !['wallet', 'points'].contains(paymentMethod)) {
      throw Exception('Select at least one item and a valid payment method.');
    }

    final orderRef = _firestore.collection('orders').doc();
    final userRef = _firestore.collection('users').doc(userId);
    final requestedProducts = <String, ProductModel>{};
    final quantities = <String, int>{};
    for (final entry in items.entries) {
      if (entry.value <= 0) {
        throw Exception('Item quantities must be greater than zero.');
      }
      requestedProducts[entry.key.id] = entry.key;
      quantities.update(
        entry.key.id,
        (quantity) => quantity + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    final productIds = quantities.keys.toList();
    if (productIds.isEmpty) {
      throw Exception('Select at least one item and a valid payment method.');
    }

    return _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw Exception('Customer profile not found.');
      final userData = userSnapshot.data();
      if (userData == null) throw Exception('Customer profile data is missing.');

      final productSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final productId in productIds) {
        productSnapshots.add(
          await transaction.get(
            _firestore.collection('products').doc(productId),
          ),
        );
      }

      final balance = (userData['walletBalance'] as num?)?.toDouble() ?? 0;
      final points = (userData['rewardPoints'] as num?)?.toInt() ?? 0;
      final orderItems = <Map<String, dynamic>>[];
      var totalCash = 0.0;
      var totalPoints = 0;
      for (var index = 0; index < productIds.length; index++) {
        final productId = productIds[index];
        final quantity = quantities[productId];
        final requestedProduct = requestedProducts[productId];
        if (quantity == null || requestedProduct == null) {
          throw Exception('Order contains an invalid product.');
        }
        final productSnapshot = productSnapshots[index];
        if (!productSnapshot.exists) {
          throw Exception(
            '${requestedProduct.name} is no longer available.',
          );
        }
        final productData = productSnapshot.data();
        if (productData == null) {
          throw Exception('${requestedProduct.name} data is unavailable.');
        }
        final stock = (productData['stock'] as num?)?.toInt() ?? 0;
        final reserved = (productData['reservedStock'] as num?)?.toInt() ?? 0;
        if (stock - reserved < quantity) {
          throw Exception(
            'Not enough ${requestedProduct.name} in stock.',
          );
        }
        final unitPrice = (productData['price'] as num?)?.toDouble() ?? 0;
        final unitPoints = (productData['pointsCost'] as num?)?.toInt() ?? 0;
        if (!unitPrice.isFinite ||
            unitPrice < 0 ||
            unitPoints < 0 ||
            (paymentMethod == 'points' && unitPoints <= 0)) {
          throw Exception('A product has invalid pricing.');
        }
        totalCash += unitPrice * quantity;
        totalPoints += unitPoints * quantity;

        orderItems.add({
          'productId': productId,
          'name': productData['name'] ?? requestedProduct.name,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'unitPoints': unitPoints,
        });
      }

      if (paymentMethod == 'wallet' && balance < totalCash) {
        throw Exception('Insufficient wallet balance.');
      }
      if (paymentMethod == 'points' && points < totalPoints) {
        throw Exception('Insufficient reward points.');
      }

      if (paymentMethod == 'wallet') {
        transaction.update(userRef, {'walletBalance': balance - totalCash});
      } else {
        transaction.update(userRef, {'rewardPoints': points - totalPoints});
      }

      for (var index = 0; index < productIds.length; index++) {
        final quantity = quantities[productIds[index]];
        if (quantity == null) {
          throw Exception('Order contains an invalid product quantity.');
        }
        transaction.update(productSnapshots[index].reference, {
          'reservedStock': FieldValue.increment(quantity),
        });
      }

      transaction.set(orderRef, {
        'userId': userId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'totalPaid': paymentMethod == 'wallet' ? totalCash : totalPoints,
        'paymentMethod': paymentMethod,
        'status': 'PENDING_APPROVAL',
        'items': orderItems,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return orderRef.id;
    });
  }

  Future<void> approveOrder(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) throw Exception('Order no longer exists.');

      final order = orderSnapshot.data();
      if (order == null) throw Exception('Order data is missing.');
      if (order['status'] != 'PENDING_APPROVAL') {
        throw Exception('This order has already been reviewed.');
      }
      final rawItems = order['items'];
      if (rawItems is! List || rawItems.isEmpty) {
        throw Exception('Order has no valid items.');
      }

      final itemMaps = rawItems.cast<Map<String, dynamic>>();
      final productSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final item in itemMaps) {
        final productId = (item['productId'] ?? '').toString();
        if (productId.isEmpty) {
          throw Exception('Order contains an invalid item.');
        }
        productSnapshots.add(
          await transaction
              .get(_firestore.collection('products').doc(productId)),
        );
      }

      for (var index = 0; index < itemMaps.length; index++) {
        final productSnapshot = productSnapshots[index];
        final quantity = (itemMaps[index]['quantity'] as num?)?.toInt() ?? 0;
        if (!productSnapshot.exists || quantity <= 0) {
          throw Exception('Order inventory is no longer valid.');
        }
        final product = productSnapshot.data();
        if (product == null) {
          throw Exception('Order inventory data is missing.');
        }
        final stock = (product['stock'] as num?)?.toInt() ?? 0;
        final reserved = (product['reservedStock'] as num?)?.toInt() ?? 0;
        if (stock < quantity || reserved < quantity) {
          throw Exception('Reserved stock is unavailable. Review inventory.');
        }
      }

      for (var index = 0; index < itemMaps.length; index++) {
        final quantity = (itemMaps[index]['quantity'] as num).toInt();
        transaction.update(productSnapshots[index].reference, {
          'stock': FieldValue.increment(-quantity),
          'reservedStock': FieldValue.increment(-quantity),
        });
      }
      transaction.update(orderRef, {
        'status': 'READY_FOR_PICKUP',
        'approvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectOrder(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) throw Exception('Order no longer exists.');

      final order = orderSnapshot.data();
      if (order == null) throw Exception('Order data is missing.');
      if (order['status'] != 'PENDING_APPROVAL') {
        throw Exception('This order has already been reviewed.');
      }
      final rawItems = order['items'];
      if (rawItems is! List || rawItems.isEmpty) {
        throw Exception('Order has no valid items.');
      }
      final itemMaps = rawItems.cast<Map<String, dynamic>>();
      final productSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      final userRef = _firestore
          .collection('users')
          .doc((order['userId'] ?? '').toString());

      final userSnapshot = await transaction.get(userRef);
      for (final item in itemMaps) {
        productSnapshots.add(
          await transaction.get(
            _firestore
                .collection('products')
                .doc((item['productId'] ?? '').toString()),
          ),
        );
      }

      for (var index = 0; index < itemMaps.length; index++) {
        final quantity = (itemMaps[index]['quantity'] as num?)?.toInt() ?? 0;
        final productSnapshot = productSnapshots[index];
        if (productSnapshot.exists && quantity > 0) {
          transaction.update(productSnapshot.reference, {
            'reservedStock': FieldValue.increment(-quantity),
          });
        }
      }

      if (!userSnapshot.exists) {
        throw Exception('Customer profile not found; cannot refund order.');
      }
      final amount = (order['totalPaid'] as num?)?.toDouble() ?? 0;
      if (order['paymentMethod'] == 'points') {
        transaction.update(userRef, {
          'rewardPoints': FieldValue.increment(amount.toInt()),
        });
      } else {
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(amount),
        });
      }
      transaction.update(orderRef, {
        'status': 'REJECTED',
        'refundedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markOrderHandedOver(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) throw Exception('Order no longer exists.');
      if (orderSnapshot.data()?['status'] != 'READY_FOR_PICKUP') {
        throw Exception('Only approved orders can be handed over.');
      }
      transaction.update(orderRef, {
        'status': 'HANDED_OVER',
        'handedOverAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitTopUpRequest({
    required String userId,
    required double amount,
    required File imageFile,
  }) async {
    final fileName =
        'topups/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(fileName);
    final snapshot = await ref.putFile(imageFile);
    final downloadUrl = await snapshot.ref.getDownloadURL();
    final transaction = WalletTransactionModel(
      id: '',
      userId: userId,
      amount: amount,
      type: 'topup',
      proofOfPaymentUrl: downloadUrl,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    await _firestore.collection('wallet_transactions').add(transaction.toMap());
  }
}
